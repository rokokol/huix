#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
sync.sh — huix repository sync (alias: syssync)

Usage:
  sync.sh                pull --rebase, stage everything, commit "[host] sync <date>", push
  sync.sh "message"      the same, with your own commit subject
  sync.sh --pull-only    fetch + merge --ff-only and nothing else (what sync.service runs)
  sync.sh --help         this help

The history is written by hand. The session/rebuild unit only fast-forwards, so it never
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

MODE=commit
case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  --pull-only)
    MODE=pull
    shift
    ;;
esac
MESSAGE="$*"

DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
HUIX_PATH="${HUIX:-$HOME/huix}"
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=2}"
HOST_NAME="$(uname -n)"

export GIT_SSH_COMMAND

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
  git commit -m "[$HOST_NAME] ${MESSAGE:-sync $(date -Iseconds)}"
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
