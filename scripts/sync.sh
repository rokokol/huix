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

Both modes end by fast-forwarding every git repository under ~/Projects (PROJECTS_DIR
overrides it). That sweep only ever fast-forwards: it never rebases, never commits, never
pushes and never touches a repository that would lose work by moving — one that has no
upstream, or whose branch has diverged, is counted and left alone. A repository holding a
.nosync file is skipped before it is even fetched

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

# Fast-forward every repository under PROJECTS_DIR. Fetching is the slow half and the
# repositories are independent, so it runs in parallel; merging is local and stays serial
sweep_projects() {
  local dir="${PROJECTS_DIR:-$HOME/Projects}"
  [ -d "$dir" ] || return 0

  local repo behind updated=0 held=0 names=""
  local -a repos=()
  for repo in "$dir"/*/; do
    [ -d "$repo.git" ] || continue
    # An opt-out for a repository whose fetch is not worth the login: a nixpkgs clone costs
    # seconds and megabytes to learn it is still a million commits behind
    [ -e "$repo.nosync" ] && continue
    # No upstream means nothing to fast-forward to, not a failure worth reporting
    git -C "$repo" rev-parse --symbolic-full-name '@{u}' >/dev/null 2>&1 || continue
    repos+=("$repo")
  done
  [ "${#repos[@]}" -gt 0 ] || return 0

  # A dead remote must not hold the login hostage, so each fetch carries its own timeout and
  # a failure only means that repository stays where it is
  printf '%s\0' "${repos[@]}" |
    xargs -0 -P 8 -I{} timeout 30 git -C {} fetch --quiet || true

  for repo in "${repos[@]}"; do
    behind=$(git -C "$repo" rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)
    [ "$behind" -gt 0 ] || continue
    if git -C "$repo" merge --ff-only '@{u}' >/dev/null 2>&1; then
      updated=$((updated + 1))
      names="$names $(basename "$repo")"
    else
      # Diverged, or a dirty file in the way: both are the user's call, never ours
      held=$((held + 1))
    fi
  done

  [ "$updated" -gt 0 ] && notify low "Projects: $updated updated (⌒‿⌒)" "${names# }"
  [ "$held" -gt 0 ] && notify normal "Projects: $held held back (・_・;)" "diverged or dirty — sync them by hand"
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
