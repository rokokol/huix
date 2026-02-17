#!/bin/sh
cd "$HUIX" || {
  notify-send "No dir 💀"
  exit 1
}

OLD_REV=$(git rev-parse HEAD)
if ! git pull; then
  notify-send "Sync Error (#｀ε´#ゞ"
else
  notify-send "Synchronized （´ω｀♡%）" "$(git log "$OLD_REV..$NEW_REV" --oneline)"
fi
NEW_REV=$(git rev-parse HEAD)

git add .
if ! git commit -m "sync $(date) from $(hostname)"; then
  notify-send "Nothing to pull (((o(*ﾟ▽ﾟ*)o)))"
  exit 1
fi

if ! git push; then
  notify-send "Push Error (#｀ε´#ゞ"
else
  notify-send "Pushed （´ω｀♡%）" "$(git log -1 --pretty=%B)"
fi
