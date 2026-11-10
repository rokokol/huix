#!/usr/bin/env bash
# Screenshot to the clipboard with a notification that shows the size of the PNG itself: on a
# scaled output grim captures in physical pixels, so the picture is larger than the selection
# Needs bash 3.2 and POSIX tools only
set -euo pipefail

usage() {
  cat <<'EOF'
shot-copy.sh — screenshot to the clipboard with a preview of its size

  shot-copy.sh             select a region and copy it
  shot-copy.sh full        copy the whole screen
  shot-copy.sh help        this text

The picture goes to the clipboard at once and a notification shows its size; the file lives
five seconds and is removed. The size is the one of the PNG, which on a scaled output is
larger than the selection. Cancelling the selection copies nothing and exits 0
EOF
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

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
size="$(identify -format '%w×%h' "$file")"
notify-send -u low -i "$file" "Copied" "$size px"
sleep 5
rm -f "$file"
