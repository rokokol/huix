#!/usr/bin/env bash
# Needs bash 4.0 for arrays with +=; runs only on this NixOS pair, never on macOS
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
  sync.sh --no-projects  skip the Projects sweep, huix only
  sync.sh --help         this help

Both modes end by catching every git repository under ~/Projects up to its upstream
(PROJECTS_DIR overrides the directory). Without local commits it fast-forwards; with them it
rebases them on top, autostashing a dirty tree, and winds the whole thing back if that would
conflict. It never commits and never pushes, a repository with no upstream is left alone, and
one holding a .git/nosync file is skipped before it is even fetched. A name marked * in the
summary was rebased rather than fast-forwarded

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

# Catch every repository under PROJECTS_PATH up to its upstream. Fetching is the slow half and
# the repositories are independent, so it runs in parallel; moving a branch is local and serial
sweep_projects() {
  local dir="$PROJECTS_PATH"
  [ -d "$dir" ] || return 0

  local repo behind ahead
  local updated=0 held=0 failed=0
  local names="" held_names="" failed_names=""
  local -a repos=()

  for repo in "$dir"/*/; do
    [ -d "$repo.git" ] || continue

    # An opt-out for a repository whose fetch is not worth the login: a nixpkgs clone costs
    # seconds and megabytes to learn it is still a million commits behind. The marker lives
    # inside .git, where no .gitignore is needed and no status line appears for it
    [ -e "$repo.git/nosync" ] && continue

    # No upstream means nothing to fast-forward to, not a failure worth reporting
    git -C "$repo" rev-parse --symbolic-full-name '@{u}' >/dev/null 2>&1 || continue

    repos+=("$repo")
  done

  [ "${#repos[@]}" -gt 0 ] || return 0

  # Parallel fetches cannot mutate our arrays, so failed repository paths are written to a
  # temporary file and collected afterwards.
  local failed_file
  failed_file=$(mktemp)
  trap 'rm -f "$failed_file"' RETURN

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
  *) break ;;
  esac
done
MESSAGE="$*"

DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
HUIX_PATH="${HUIX:-$HOME/huix}"
# Both paths come from the unit's Environment, where the flake spells them once; the fallbacks
# are for a hand call from a terminal, which inherits neither
PROJECTS_PATH="${PROJECTS_DIR:-$HOME/Projects}"
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=2}"

export GIT_SSH_COMMAND

# On EXIT rather than at the end: huix leaves through five different exits, and a trap cannot
# forget one of them. It also means a huix failure still lets the other repositories catch up.
# The handler returns without exiting, so the script's own status survives it
if [ "$PROJECTS" = yes ]; then
  trap sweep_projects EXIT
fi

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

if [ "$(git rev-list --count '@{u}..HEAD')" -eq 0 ]; then
  notify low "Nothing to push ( ˘ω˘ )"
  exit 0
fi

if ! timeout 90 git push; then
  notify critical "Push Error (*≧m≦*)"
  exit 1
fi

notify low "Pushed o(^▽^)o" "$(git log -1 --pretty=%B)"
