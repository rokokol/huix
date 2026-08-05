#!/usr/bin/env bash
# Paste the clipboard contents as a file into the current Thunar folder.
# Invoked from a custom action (Ctrl+Shift+V) with %f as the first argument.
# Image -> img.png (extension by MIME), text (incl. a path string) -> text.txt.
# Thunar's file operations (Ctrl+V/Ctrl+C/Ctrl+X) are not touched by this script.
set -euo pipefail

dir="${1:-$PWD}"
# if Thunar passed a selected file rather than a folder — take its directory
[ -d "$dir" ] || dir="$(dirname "$dir")"

types="$(wl-paste --list-types 2>/dev/null || true)"

# look for an image mime; derive the extension from the subtype
img_mime=""
while IFS= read -r t; do
  case "$t" in
    image/*)
      img_mime="$t"
      break
      ;;
  esac
done <<<"$types"

if [ -n "$img_mime" ]; then
  base="img"
  sub="${img_mime#image/}"
  case "$sub" in
    jpeg) ext="jpg" ;;
    svg+xml) ext="svg" ;;
    x-*) ext="${sub#x-}" ;;
    *) ext="$sub" ;;
  esac
  mime="$img_mime"
elif grep -qx 'text/plain;charset=utf-8' <<<"$types"; then
  base="text"
  ext="txt"
  mime="text/plain;charset=utf-8"
elif grep -qx 'text/plain' <<<"$types"; then
  base="text"
  ext="txt"
  mime="text/plain"
elif grep -qx 'text/uri-list' <<<"$types"; then
  # clipboard = a file copy; on purpose we write the path as a text file rather than copying the file
  base="text"
  ext="txt"
  mime="text/uri-list"
else
  # clipboard is empty or the type is unsupported — exit silently, no notifications
  exit 0
fi

# unique name: img.png, img-1.png, img-2.png, ...
name="$base.$ext"
i=1
while [ -e "$dir/$name" ]; do
  name="$base-$i.$ext"
  i=$((i + 1))
done

wl-paste --type "$mime" >"$dir/$name"
