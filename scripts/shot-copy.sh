#!/usr/bin/env bash

set -euo pipefail

# Screenshot to the clipboard + a preview notification, the file is removed after 5 s
# $1: region (interactive selection, default) | full (the whole screen)
mode="${1:-region}"
file="/tmp/shot_$(date +%s).png"

if [[ "$mode" == "region" ]]; then
  geom="$(slurp -b ffffff66 -w 1)" || exit 0
  sleep 0.2
  grim -g "$geom" "$file"
else
  grim "$file"
fi

wl-copy <"$file"
notify-send -i "$file" "Copied"
sleep 5
rm -f "$file"
