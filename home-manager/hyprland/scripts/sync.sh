#!/usr/bin/env bash
DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$(id -u)/bus"
export DBUS_SESSION_BUS_ADDRESS
HUIX_PATH="${HUIX:-/home/rokokol/huix}"

cd "$HUIX_PATH" || {
  notify-send -u critical "No dir $HUIX_PATH 💀"
  exit 1
}

OLD_REV=$(git rev-parse HEAD)
if ! git pull; then
  notify-send -u critical "Sync Error (#｀ε´#ゞ"
else
  notify-send -u low "Synchronized （´ω｀♡%）" "$(git log "$OLD_REV..$NEW_REV" --oneline)"
fi
NEW_REV=$(git rev-parse HEAD)

git add .
if ! git commit -m "sync $(date) from $(hostname)"; then
  notify-send -u low "Nothing to pull (((o(*ﾟ▽ﾟ*)o)))"
  exit 0
fi

if ! git push; then
  notify-send -u critical "Push Error (*≧m≦*)"
else
  notify-send -u low "Pushed o(^▽^)o" "$(git log -1 --pretty=%B)"
fi
