#!/usr/bin/env bash
# Needs bash 4.3 for local -n; runs only on this NixOS pair, never on macOS
# The "[host]" the subject ends up with is put there by scripts/git-hooks/prepare-commit-msg,
# not by this script

set -euo pipefail

usage() {
  cat <<'EOF'
sync.sh — huix repository sync (alias: syssync)

Usage:
  sync.sh                pull --rebase, stage everything, commit "[host] sync <date>", push
  sync.sh "message"      the same, with your own commit subject
  sync.sh --pull-only    fetch + merge --ff-only and nothing else (what sync.service runs)
  sync.sh --no-projects  skip the sweep below, huix only
  sync.sh --no-take      leave the agents' clones alone, see below
  sync.sh --help         this help

Exit 0 when huix is in sync, 1 when a git step failed, timed out or left a conflict. The
sweep never decides the status: a repository it could not move is reported and passed over

The commit mode also takes an agent's work into huix. That holds for each line of the
SYNC_REMOTES file below with huix's origin and a fourth field UNIT. First UNIT starts over ssh
on the host before the colon of URL: it commits whatever the agent left as "[USER] sync DATE"
and rebases the agent's clone on GitHub. After huix's own commit, each commit of the clone that
huix lacks is cherry-picked, and the owner hears what was taken under the remote's name. When
something was taken, huix pulls once more, which drops a copy of an upstream commit the clone
got after huix's first pull. After the push UNIT starts again, and the clone drops its copies
of what is now upstream. An agent out of reach is reported and passed over. A conflict is
wound back, leaves the agent's commits in its clone and makes the exit status 1

Both modes end by catching every git repository under ~/Projects and under the shared Claude
skills up to its upstream; PROJECTS_DIR and SKILLS_DIR name those two directories. The search
is recursive, but stops at the first directory containing .git. Without local commits it
fast-forwards; with them it rebases them on top, autostashing a dirty tree, and winds the whole
thing back if that would conflict. It never commits and never pushes, a repository with no
upstream is left alone, and one holding a .git/nosync file is skipped before it is even
fetched. A name marked * in the summary was rebased rather than fast-forwarded

Before that, each line "NAME ORIGIN URL [UNIT]" of the file SYNC_REMOTES gives every checkout
whose origin is ORIGIN, huix and the sweep's own, a remote NAME at URL. The remote is fetched,
and its commits that no branch holds are reported; it is removed once its line is gone. Only
the commit mode above merges, into huix and from a line with a UNIT. A remote not made from
that file is never touched, and --no-projects limits this to huix

The huix history is written by hand. The session/rebuild unit only fast-forwards, so it never
rebases local commits and never touches a dirty tree — when it cannot fast-forward it just
says so. Staging is -A, so a new file goes up without a separate git add
EOF
}

notify() {
  local urgency=$1 title=$2 body=${3:-}

  notify-send -u "$urgency" "$title" "$body" || true
  # syssync is called from a terminal — there the answer belongs on stdout
  if [ -t 1 ]; then
    printf '%s\n' "$title" ${body:+"$body"}
  fi
}

# Append every git repository under DIR to the array named by the second argument, stopping
# at the first directory that holds .git
collect_repos() {
  local current_dir=${1%/} child
  local -n into=$2

  [ -e "$current_dir/.git" ] && {
    into+=("$current_dir")
    return 0
  }

  for child in "$current_dir"/*/ "$current_dir"/.[!.]*/ "$current_dir"/..?*/; do
    [ -d "$child" ] || continue
    collect_repos "$child" "$2"
  done
}

# Every repository under the PROJECTS_PATH entries
project_repos() {
  local path_entry
  local -a path_entries
  IFS=':' read -ra path_entries <<< "$PROJECTS_PATH"
  for path_entry in "${path_entries[@]}"; do
    [ -d "$path_entry" ] && collect_repos "$path_entry" "$1"
  done
  return 0
}

# A remote URL reduced to host and path, so that git@host:a/b.git and https://host/a/b match
url_key() {
  local url=${1%/}
  url=${url%.git}
  url=${url#*://}
  url=${url#*@}
  printf '%s\n' "${url/:/\/}"
}

# Each line of the SYNC_REMOTES file is "NAME ORIGIN URL": a repository whose origin is ORIGIN
# gets the remote NAME at URL. The remote is only fetched here; take_agents is what merges, and
# only into huix. A remote this made carries
# remote.NAME.huixSync, so one that leaves the list is removed and no other remote is touched
sync_remotes() {
  local list=${SYNC_REMOTES:-}
  [ -n "$list" ] || return 0

  local -a candidates=("$HUIX_PATH") lines=()
  [ "$PROJECTS" = yes ] && project_repos candidates
  [ -r "$list" ] && mapfile -t lines <"$list"

  local repo origin line name want url managed new
  local -A news=() failed=()
  for repo in "${candidates[@]}"; do
    [ -e "$repo/.git" ] || continue
    origin=$(git -C "$repo" config --get remote.origin.url) || continue
    local -A wanted=()

    for line in "${lines[@]}"; do
      read -r name want url _ <<<"$line"
      [ -n "${url:-}" ] && [ "$(url_key "$want")" = "$(url_key "$origin")" ] || continue
      wanted[$name]=1
      if git -C "$repo" config --get "remote.$name.url" >/dev/null; then
        git -C "$repo" remote set-url "$name" "$url"
      else
        git -C "$repo" remote add "$name" "$url"
      fi
      git -C "$repo" config "remote.$name.huixSync" true

      if ! timeout 30 git -C "$repo" fetch --quiet "$name" 2>/dev/null; then
        failed[$name]+=" $(basename "$repo")"
        continue
      fi
      # Only what the owner holds nowhere: the agent's clone also carries everything it pulled
      new=$(git -C "$repo" rev-list --count --remotes="$name" \
        --not --exclude="$name/*" --remotes --branches)
      [ "$new" -gt 0 ] && news[$name]+=" $(basename "$repo") $new"
    done

    while read -r managed _; do
      managed=${managed#remote.}
      managed=${managed%.huixsync}
      [ -n "$managed" ] && [ -z "${wanted[$managed]:-}" ] &&
        git -C "$repo" remote remove "$managed"
    done < <(git -C "$repo" config --get-regexp '^remote\..*\.huixsync$' || true)
    unset wanted
  done

  for name in "${!news[@]}"; do
    notify normal "New commits on $name (=^･ω･^=)" \
      "${news[$name]# }"$'\n'"git log -p --remotes=$name --not --branches"
  done
  for name in "${!failed[@]}"; do
    notify low "Fetch from $name failed (・_・;)" "${failed[$name]# }"
  done
  return 0
}

# The lines of the SYNC_REMOTES file for huix that name an agent's sync unit, as "NAME URL UNIT"
agent_lines() {
  local list=${SYNC_REMOTES:-} origin name want url unit
  [ -n "$list" ] && [ -r "$list" ] || return 0
  origin=$(git -C "$HUIX_PATH" config --get remote.origin.url) || return 0
  while read -r name want url unit; do
    [ -n "${unit:-}" ] && [ "$(url_key "$want")" = "$(url_key "$origin")" ] || continue
    printf '%s %s %s\n' "$name" "$url" "$unit"
  done <"$list"
}

# Start the sync unit of every agent on its host. An agent whose unit did not run is put in
# AGENT_DOWN, and nothing is taken from it
start_agents() {
  local line name url unit
  for line in "${AGENTS[@]}"; do
    read -r name url unit <<<"$line"
    [ -z "${AGENT_DOWN[$name]:-}" ] || continue
    if ! timeout 120 ssh -n "${SSH_OPTS[@]}" "${url%%:*}" systemctl start "$unit"; then
      AGENT_DOWN[$name]=1
      notify normal "Sync of $name failed (・_・;)" "$unit on ${url%%:*}"
    fi
  done
}

# Cherry-pick each commit of an agent's clone that HEAD lacks, and set TOOK. A commit that turns
# out empty is dropped, as the same change already came another way. The clone may hold an
# upstream commit that came after huix pulled; the pull before the push drops its copy
take_agents() {
  local line name url unit before
  local -a commits
  for line in "${AGENTS[@]}"; do
    read -r name url unit <<<"$line"
    [ -z "${AGENT_DOWN[$name]:-}" ] || continue
    if ! timeout 30 git fetch --quiet "$url" HEAD; then
      notify low "Fetch from $name failed (・_・;)" "$(basename "$HUIX_PATH")"
      continue
    fi
    mapfile -t commits < <(git rev-list --reverse --no-merges HEAD..FETCH_HEAD)
    [ "${#commits[@]}" -gt 0 ] || continue

    before=$(git rev-parse HEAD)
    if git cherry-pick --empty=drop "${commits[@]}" >/dev/null; then
      TOOK=1
      notify low "Took $(git rev-list --count "$before..HEAD") commits from $name (=^･ω･^=)" \
        "$(git log --format=%s "$before..HEAD")"
    else
      git cherry-pick --abort || true
      TAKE_STATUS=1
      notify critical "Conflict with $name (╯°□°）╯︵ ┻━┻" \
        "Its commits stay in its clone"$'\n'"git log -p --remotes=$name --not --branches"
    fi
  done
}

# Catch every repository under the PROJECTS_PATH entries up to its upstream. Fetching is the
# slow half and the repositories are independent, so it runs in parallel; moving a branch is
# local and serial
sweep_projects() {
  local repo behind ahead
  local updated=0 held=0 failed=0
  local names="" held_names="" failed_names=""
  local -a found=() repos=()

  project_repos found
  for repo in "${found[@]}"; do
    git -C "$repo" rev-parse --symbolic-full-name '@{u}' >/dev/null 2>&1 || continue
    [ -e "$repo/.git/nosync" ] || repos+=("$repo")
  done

  [ "${#repos[@]}" -gt 0 ] || return 0

  # Parallel fetches cannot mutate the caller's arrays, so failed repository paths are
  # written to a temporary file and collected afterwards.
  local failed_file
  failed_file=$(mktemp)
  # The trap clears itself, or it fires again on the caller's return, where the local is gone
  trap 'rm -f "$failed_file"; trap - RETURN' RETURN

  export failed_file

  printf '%s\0' "${repos[@]}" |
    xargs -0 -P 8 -I{} bash -c '
      repo=$1

      if ! timeout 30 git -C "$repo" fetch --quiet; then
        name=$(basename "$repo")
        printf "Fetch failed: %s\n" "$name" >&2
        printf "%s\n" "$repo" >>"$failed_file"
      fi
    ' _ {}

  local -A fetch_failed=()
  while IFS= read -r repo; do
    [ -n "$repo" ] || continue
    fetch_failed["$repo"]=1
    failed=$((failed + 1))
    failed_names="$failed_names $(basename "$repo")"
  done <"$failed_file"

  for repo in "${repos[@]}"; do
    # Do not move a repository when its remote could not be fetched: @{u} may be stale.
    if [[ -n "${fetch_failed[$repo]:-}" ]]; then
      continue
    fi

    behind=$(git -C "$repo" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
    [ "$behind" -gt 0 ] || continue

    ahead=$(git -C "$repo" rev-list --count '@{u}..HEAD' 2>/dev/null || echo 0)

    if [ "$ahead" -eq 0 ]; then
      if git -C "$repo" merge --ff-only '@{u}' >/dev/null 2>&1; then
        updated=$((updated + 1))
        names="$names $(basename "$repo")"
      else
        held=$((held + 1))
        held_names="$held_names $(basename "$repo")"
      fi
    elif git -C "$repo" rebase --autostash '@{u}' >/dev/null 2>&1; then
      updated=$((updated + 1))
      names="$names $(basename "$repo")*"
    else
      git -C "$repo" rebase --abort >/dev/null 2>&1 || true
      held=$((held + 1))
      held_names="$held_names $(basename "$repo")"
    fi
  done

  [ "$updated" -gt 0 ] &&
    notify low "Projects: $updated updated (⌒‿⌒)" "${names# }"

  [ "$held" -gt 0 ] &&
    notify normal "Projects: $held held back (・_・;)" \
      "${held_names# }"$'\n'"diverged, conflicting or dirty — sync them by hand"

  [ "$failed" -gt 0 ] &&
    notify normal "Projects: $failed fetch failed (╥﹏╥)" \
      "${failed_names# }"

  return 0
}

MODE=commit
PROJECTS=yes
TAKE=yes
while :; do
  case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  --pull-only)
    MODE=pull
    shift
    ;;
  --no-projects)
    PROJECTS=no
    shift
    ;;
  --no-take)
    TAKE=no
    shift
    ;;
  *) break ;;
  esac
done
MESSAGE="$*"

DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
# Home Manager sets all three for the session and repeats the last two in the unit, which
# inherits no session variable. The fallback is for a call from a shell that has neither
HUIX_PATH="${HUIX:-$HOME/huix}"
PROJECTS_PATH="${PROJECTS_DIR:-$HOME/Projects}${SKILLS_DIR:+:$SKILLS_DIR}"
SSH_OPTS=(-o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=2)
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh ${SSH_OPTS[*]}}"

export GIT_SSH_COMMAND

# On EXIT rather than at the end: huix leaves through five different exits, and a trap cannot
# forget one of them. It also means a huix failure still lets the other repositories catch up.
# The handler returns without exiting, so the script's own status survives it
on_exit() {
  sync_remotes
  if [ "$PROJECTS" = yes ]; then
    sweep_projects
  fi
}
trap on_exit EXIT

cd "$HUIX_PATH" || {
  notify critical "No dir $HUIX_PATH 💀"
  exit 1
}

if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  notify low "Sync Error" "No upstream branch configured (;¬_¬)"
  exit 1
fi

OLD_REV=$(git rev-parse HEAD)

if [ "$MODE" = pull ]; then
  if ! timeout 90 git fetch; then
    notify critical "Fetch Error (#｀ε´#ゞ" "git fetch failed or timed out"
    exit 1
  fi

  BEHIND=$(git rev-list --count 'HEAD..@{u}')
  if [ "$BEHIND" -eq 0 ]; then
    exit 0
  fi

  if ! git merge --ff-only '@{u}'; then
    notify normal "Upstream ahead by $BEHIND (・_・;)" "No fast-forward from here — call syssync"
    exit 0
  fi

  notify low "Synchronized （´ω｀♡%）" "$(git log "$OLD_REV..HEAD" --oneline)"
  exit 0
fi

# The agents commit and rebase on GitHub before huix pulls, so every commit of theirs that the
# upstream lacks is their own work
AGENTS=()
declare -A AGENT_DOWN=()
TAKE_STATUS=0
TOOK=0
[ "$TAKE" = yes ] && mapfile -t AGENTS < <(agent_lines)
start_agents

if ! timeout 90 git pull --rebase --autostash; then
  notify critical "Sync Error (#｀ε´#ゞ" "git pull failed or timed out"
  exit 1
fi

if [ "$OLD_REV" != "$(git rev-parse HEAD)" ]; then
  notify low "Synchronized （´ω｀♡%）" "$(git log "$OLD_REV..HEAD" --oneline)"
fi

# The autostash pop can conflict while the rebase itself succeeds, and git still exits 0
if [ -n "$(git ls-files --unmerged)" ]; then
  notify critical "Conflict (╯°□°）╯︵ ┻━┻" "Resolve it by hand, then call syssync again"
  exit 1
fi

git add -A
if git diff --cached --quiet; then
  notify low "Nothing to commit (((o(*ﾟ▽ﾟ*)o)))"
else
  # The host prefix comes from scripts/git-hooks/prepare-commit-msg, which every commit in this
  # repository goes through — writing it here too would only produce it twice
  git commit -m "${MESSAGE:-sync $(date -Iseconds)}"
fi

take_agents
if [ "$TOOK" = 1 ] && ! timeout 90 git pull --quiet --rebase; then
  git rebase --abort 2>/dev/null || true
  notify critical "Sync Error (#｀ε´#ゞ" "git pull after taking the agents' commits failed"
  exit 1
fi

if [ "$(git rev-list --count '@{u}..HEAD')" -eq 0 ]; then
  notify low "Nothing to push ( ˘ω˘ )"
elif ! timeout 90 git push; then
  notify critical "Push Error (*≧m≦*)"
  exit 1
else
  notify low "Pushed o(^▽^)o" "$(git log -1 --pretty=%B)"
fi

# Once more, so each clone catches up with the push and drops its copies of the taken commits
start_agents
exit "$TAKE_STATUS"
