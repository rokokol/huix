#!/usr/bin/env bash
# Paste the clipboard contents as a file into a folder, and print the path of the new file
# Invoked from Thunar's custom action (Ctrl+Shift+V) with %f as the first argument; yazi does
# the same in its clipboard-sync plugin, and this script goes with Thunar
# Image -> img.png (extension by MIME), text (incl. a path string) -> text.txt
set -euo pipefail

dir="${1:-$PWD}"
# a selected file rather than a folder stands for the folder it is in
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
  # clipboard = a file copy; the path is written as a text file on purpose, rather than
  # the file being copied
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

wl-paste --no-newline --type "$mime" >"$dir/$name"
printf '%s\n' "$dir/$name"
