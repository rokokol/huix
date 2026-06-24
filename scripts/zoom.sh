#!/usr/bin/env bash

# Живая лупа: зум экрана вокруг курсора через Hyprland cursor:zoom_factor.
set -euo pipefail

action=${1:-toggle}
step=${2:-1.3}
min=1.0
max=20.0

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
  echo "usage: zoom.sh in|out|reset|toggle [step]" >&2
  exit 1
}

hyprctl keyword cursor:zoom_factor "$new" >/dev/null
