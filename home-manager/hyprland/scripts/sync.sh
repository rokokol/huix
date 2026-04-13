#!/usr/bin/env bash

set -euo pipefail

notify() {
  notify-send "$@" || true
}

DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
HUIX_PATH="${HUIX:-$HOME/huix}"
GIT_TERMINAL_PROMPT=0
GIT_SSH_COMMAND="${GIT_SSH_COMMAND:-ssh -o BatchMode=yes -o ConnectTimeout=15 -o ServerAliveInterval=15 -o ServerAliveCountMax=2}"
HOST_NAME="$(uname -n)"

export GIT_TERMINAL_PROMPT
export GIT_SSH_COMMAND

cd "$HUIX_PATH" || {
  notify -u critical "No dir $HUIX_PATH 💀"
  exit 1
}

OLD_REV=$(git rev-parse HEAD)
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  notify -u low "Sync Error" "No upstream branch configured (;¬_¬)"
  exit 1
fi

if ! timeout 90 git pull --rebase --autostash; then
  notify -u critical "Sync Error (#｀ε´#ゞ" "git pull failed or timed out"
  exit 1
fi

NEW_REV=$(git rev-parse HEAD)
notify -u low "Synchronized （´ω｀♡%）" "$(git log "$OLD_REV..$NEW_REV" --oneline)"

git add --all
if ! git commit -m "sync $(date) from $HOST_NAME"; then
  notify -u low "Nothing to commit (((o(*ﾟ▽ﾟ*)o)))"
  if [ "$(git rev-list @\{u\}..HEAD | wc -l)" -gt 0 ]; then
    if ! timeout 90 git push; then
      notify -u critical "Push Error (*≧m≦*)"
    else
      notify -u low "Pushed ⊂(‘ω’⊂ )))Σ≡=─༄༅༄༅༄༅༄༅༄༅" "$(git log -1 --pretty=%B)"
    fi
  fi
  exit 0
fi

if ! timeout 90 git push; then
  notify -u critical "Push Error (*≧m≦*)"
else
  notify -u low "Pushed o(^▽^)o" "$(git log -1 --pretty=%B)"
fi
