#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
zoom.sh — живая лупа: зум экрана вокруг курсора (Hyprland cursor:zoom_factor)

Использование:
  zoom.sh in|out [шаг]   ближе/дальше (множитель, по умолчанию 1.3)
  zoom.sh toggle         2.5x или обратно 1x (по умолчанию)
  zoom.sh reset          1x
  zoom.sh --help         эта справка
EOF
}

action=${1:-toggle}
step=${2:-1.3}
min=1.0
max=20.0

case "$action" in
help | -h | --help)
  usage
  exit 0
  ;;
esac

current=$(hyprctl getoption cursor:zoom_factor -j | jq -r '.float')

new=$(awk -v c="$current" -v a="$action" -v s="$step" -v lo="$min" -v hi="$max" 'BEGIN {
  if      (a == "in")     v = c * s
  else if (a == "out")    v = c / s
  else if (a == "reset")  v = lo
  else if (a == "toggle") v = (c > lo + 0.001) ? lo : 2.5
  else { exit 1 }
  if (v > hi) v = hi
  if (v < lo) v = lo
  printf "%.4f", v
}') || {
  usage >&2
  exit 1
}

hyprctl keyword cursor:zoom_factor "$new" >/dev/null
