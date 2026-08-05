#!/usr/bin/env bash

set -euo pipefail

# OCR of a selected screen region into the clipboard.
# $1 — tesseract languages (rus+eng | rus | eng), default rus+eng.
lang="${1:-rus+eng}"

geom="$(slurp -b ffffff66 -w 1)" || exit 0
sleep 0.2

if ! text="$(grim -g "$geom" - | tesseract stdin stdout -l "$lang" 2>/dev/null)"; then
  notify-send "OCR" "OCR Error"
  exit 1
fi

printf '%s' "$text" | wl-copy
notify-send "OCR" "$text"
