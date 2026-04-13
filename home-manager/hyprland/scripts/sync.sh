#!/usr/bin/env bash

set -euo pipefail

DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
HUIX_PATH="${HUIX:-$HOME/huix}"

cd "$HUIX_PATH" || {
  notify-send -u critical "No dir $HUIX_PATH 💀"
  exit 1
}

OLD_REV=$(git rev-parse HEAD)
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  notify-send -u low "Sync Error" "No upstream branch configured (;¬_¬)"
  exit 1
fi

if ! git pull --rebase --autostash; then
  notify-send -u critical "Sync Error (#｀ε´#ゞ"
  exit 1
fi

NEW_REV=$(git rev-parse HEAD)
notify-send -u low "Synchronized （´ω｀♡%）" "$(git log "$OLD_REV..$NEW_REV" --oneline)"

git add --all
if ! git commit -m "sync $(date) from $(hostname)"; then
  notify-send -u low "Nothing to commit (((o(*ﾟ▽ﾟ*)o)))"
  if [ "$(git rev-list @\{u\}..HEAD | wc -l)" -gt 0 ]; then
    if ! git push; then
      notify-send -u critical "Push Error (*≧m≦*)"
    else
      notify-send -u low "Pushed ⊂(‘ω’⊂ )))Σ≡=─༄༅༄༅༄༅༄༅༄༅" "$(git log -1 --pretty=%B)"
    fi
  fi
  exit 0
fi

if ! git push; then
  notify-send -u critical "Push Error (*≧m≦*)"
else
  notify-send -u low "Pushed o(^▽^)o" "$(git log -1 --pretty=%B)"
fi
