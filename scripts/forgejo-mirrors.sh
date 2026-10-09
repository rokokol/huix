#!/usr/bin/env bash
# Run from a store copy by nixos/services/tools/forgejo-mirrors.nix, as the forgejo user. Both
# tokens are read from files and reach curl and jq through a pipe or the environment, never
# through their arguments, which every user on the host can read
# Needs bash 4.4, where an empty array expands under set -u, curl and jq
set -euo pipefail

usage() {
  cat <<'EOF'
forgejo-mirrors.sh — keep a Forgejo pull mirror of every GitHub repository of a user

  forgejo-mirrors.sh sync [-x NAME]... GITHUB_API GITHUB_TOKEN_FILE FORGEJO_URL FORGEJO_TOKEN_FILE OWNER STATE [FORK...]

  -x NAME   make no mirror of the repository NAME; an existing one is kept

Every repository that GITHUB_API/user/repos lists as the user's own gets a mirror under OWNER
on FORGEJO_URL, except the forks; a fork named as a FORK gets one too. A mirror is private
when its repository is, and only a private mirror is given the token, so a public one is not
touched when the token changes. Forgejo cannot change the credentials of a mirror, so when the
token differs from the one the last full run saw (its hash in STATE), each private mirror is
made again: the new one is made beside it as <name>-renewing, then takes its place. A run that
stops halfway finishes the swap the next time. A mirror whose repository left GitHub is kept,
and a repository of OWNER that is not a mirror is never touched

GITHUB_PER_PAGE sets the page size of the GitHub list, 100 by default
Exit 0 when every mirror is in place, 1 when GitHub or Forgejo refused a request or a FORK is
not among the user's repositories, 2 on a usage error
EOF
}

note() {
  printf 'forgejo-mirrors.sh: %s\n' "$1" >&2
}

die() { # the request itself is wrong
  note "$1"
  exit 2
}

renewing=-renewing

# github PATH — a GET from the GitHub API
github() {
  curl -sSf --max-time 60 -H @<(printf 'Authorization: Bearer %s\n' "$github_token") \
    -H 'Accept: application/vnd.github+json' "$github_api$1"
}

# forgejo METHOD PATH [CURL ARGUMENT...] — a call to the Forgejo API. A migration clones the
# whole repository before the answer comes, hence the long timeout
forgejo() {
  local method=$1 path=$2
  shift 2
  curl -sSf --max-time 1800 -X "$method" \
    -H @<(printf 'Authorization: token %s\n' "$forgejo_token") \
    -H 'Content-Type: application/json' "$@" "$forgejo_url/api/v1$path"
}

# migrate REPO NAME — make a mirror called NAME of REPO, a JSON object from the GitHub list
migrate() {
  GITHUB_TOKEN=$github_token jq -n --argjson repo "$1" --arg name "$2" --arg owner "$owner" '{
      clone_addr: $repo.clone_url, repo_name: $name, repo_owner: $owner, service: "git",
      mirror: true, private: $repo.private, lfs: false,
      description: "Mirror of \($repo.html_url), where its CI runs"
    } + if $repo.private
      then {auth_username: "x-access-token", auth_password: $ENV.GITHUB_TOKEN}
      else {} end' |
    forgejo POST /repos/migrate --data-binary @- >/dev/null
}

# swap NAME — put NAME-renewing in the place of NAME. It runs as an if condition, where set -e
# is off, so each step returns on its own failure
swap() {
  if jq -e --arg name "$1" 'any(.name == $name)' <<<"$have" >/dev/null; then
    forgejo DELETE "/repos/$owner/$1" >/dev/null || return 1
  fi
  jq -n --arg name "$1" '{name: $name}' |
    forgejo PATCH "/repos/$owner/$1$renewing" --data-binary @- >/dev/null
}

[[ ${1-} == sync ]] || {
  usage >&2
  exit 2
}
shift
exclusions=()
while getopts x: flag; do
  case $flag in
    x) exclusions+=("$OPTARG") ;;
    *) die "unknown option; run without arguments for help" ;;
  esac
done
shift $((OPTIND - 1))
[[ $# -ge 6 ]] || die "sync needs GITHUB_API GITHUB_TOKEN_FILE FORGEJO_URL FORGEJO_TOKEN_FILE OWNER STATE"
github_api=$1 forgejo_url=$3 owner=$5 state=$6
github_token=$(<"$2")
forgejo_token=$(<"$4")
shift 6
forks=$(jq -nc '$ARGS.positional' --args "$@")
per_page=${GITHUB_PER_PAGE:-100}

# A raw page runs to hundreds of kilobytes, past what one argument may hold, so each page is cut
# to the fields used here before it is passed on
all='[]'
page=1
while :; do
  batch=$(github "/user/repos?affiliation=owner&per_page=$per_page&page=$page" |
    jq -c 'map({name, private, fork, clone_url, html_url})') || {
    note "GitHub did not give page $page of the repository list"
    exit 1
  }
  all=$(jq -c --argjson batch "$batch" '. + $batch' <<<"$all")
  (($(jq length <<<"$batch") < per_page)) && break
  page=$((page + 1))
done

excluded=$(jq -nc '$ARGS.positional' --args "${exclusions[@]}")
wanted=$(jq -c --argjson forks "$forks" --argjson excluded "$excluded" '
  map(select((.fork | not) or (.name | IN($forks[]))))
  | map(select(.name | IN($excluded[]) | not))' <<<"$all")

status=0
for name in $(jq -r --argjson wanted "$wanted" '. - ($wanted | map(.name)) | .[]' <<<"$forks"); do
  note "$name is named as a fork to mirror, but the user has no repository by that name"
  status=1
done

have='[]'
page=1
while :; do
  batch=$(forgejo GET "/user/repos?limit=50&page=$page" |
    jq -c 'map({name, mirror, private, owner: .owner.login})') || {
    note "Forgejo did not give page $page of the repository list"
    exit 1
  }
  have=$(jq -c --argjson batch "$batch" --arg owner "$owner" \
    '. + ($batch | map(select(.owner == $owner)))' <<<"$have")
  (($(jq length <<<"$batch") < 50)) && break
  page=$((page + 1))
done

hash=$(sha256sum <<<"$github_token" | cut -d ' ' -f 1)
renew=false
if [[ -s $state/github-token.sha256 && $(<"$state/github-token.sha256") != "$hash" ]]; then
  renew=true
fi

while read -r repo; do
  name=$(jq -r .name <<<"$repo")
  mine=$(jq -c --arg name "$name" 'map(select(.name == $name)) | first // empty' <<<"$have")
  if jq -e --arg name "$name$renewing" 'any(.name == $name)' <<<"$have" >/dev/null; then
    if swap "$name"; then
      note "$name: finished the swap a stopped run began"
    else
      note "$name: could not finish the swap a stopped run began"
      status=1
    fi
  elif [[ -z $mine ]]; then
    if migrate "$repo" "$name"; then
      note "$name: mirrored"
    else
      note "$name: Forgejo did not make the mirror"
      status=1
    fi
  elif ! jq -e .mirror <<<"$mine" >/dev/null; then
    note "$name: a repository of $owner that is not a mirror has this name, so it is left alone"
  elif $renew && jq -e .private <<<"$mine" >/dev/null; then
    if migrate "$repo" "$name$renewing" && swap "$name"; then
      note "$name: mirrored again with the new token"
    else
      note "$name: could not mirror it again with the new token"
      status=1
    fi
  fi
done < <(jq -c '.[]' <<<"$wanted")

if ((status == 0)); then
  (umask 077 && printf '%s\n' "$hash" >"$state/github-token.sha256")
fi
exit "$status"
