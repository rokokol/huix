#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
ocr.sh — read the text of a selected screen region into the clipboard

  ocr.sh              recognise a selected region in Russian and English
  ocr.sh LANG         recognise it in the tesseract languages named, as in rus+eng
  ocr.sh help         this text

The picture goes to tesseract from grim without touching the disk, and the text replaces the
clipboard. A selection abandoned with Escape copies nothing and exits 0, and a failed
recognition reports itself and exits 1
EOF
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

# OCR of a selected screen region into the clipboard
lang="${1:-rus+eng}"

geom="$(slurp -b ffffff66 -w 1)" || exit 0
sleep 0.2

if ! text="$(grim -g "$geom" - | tesseract stdin stdout -l "$lang" 2>/dev/null)"; then
  notify-send "OCR" "OCR Error"
  exit 1
fi

printf '%s' "$text" | wl-copy
notify-send "OCR" "$text"
