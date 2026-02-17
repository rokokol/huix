#!/bin/sh
cd /home/rokokol/huix || notify-send "No dir 💀"

if ! git pull; then
  notify-send "Sync Error (#｀ε´#ゞ"
else
  notify-send "Synchronized （´ω｀♡%）" "$(git log -1 --pretty=%B)"
fi

git add .
git commit -m "sync $(date) from $(hostname)"

if ! git push; then
  notify-send "Push Error (#｀ε´#ゞ"
else
  notify-send "Pushed （´ω｀♡%）" "$(git log -1 --pretty=%B)"
fi
