#!/usr/bin/env bash

set -euo pipefail

tmp_dir="/tmp/cliphist_previews"
mkdir -p "$tmp_dir"

build_menu() {
  cliphist list | while IFS= read -r line; do
    case "$line" in
    *"[[ binary"*)
      id="${line%%$'\t'*}"
      img_path="$tmp_dir/$id.png"

      if [[ ! -f "$img_path" ]]; then
        cliphist decode "$id" >"$img_path" 2>/dev/null || true
      fi

      printf '%s\0icon\x1f%s\n' "$line" "$img_path"
      ;;
    *)
      printf '%s\n' "$line"
      ;;
    esac
  done
}

delete_entry() {
  local entry="$1"
  local id="${entry%%$'\t'*}"

  printf '%s\n' "$entry" | cliphist delete
  rm -f "$tmp_dir/$id.png"
}

while true; do
  if selection=$(
    build_menu | rofi \
      -dmenu \
      -i \
      -show-icons \
      -display-columns 2 \
      \
      -p "📋" \
      -mesg "Enter: копировать | Ctrl+d: удалить" \
      -kb-remove-char-forward "Delete" \
      -kb-custom-1 "Control+d" # -theme-str 'element-icon { size: 72px; } element { padding: 12px 14px; }' \
  ); then
    status=0
  else
    status=$?
  fi

  case "$status" in
  0)
    [[ -n "${selection:-}" ]] || exit 0
    printf '%s\n' "$selection" | cliphist decode | wl-copy
    exit 0
    ;;
  1)
    exit 0
    ;;
  10)
    [[ -n "${selection:-}" ]] || continue
    delete_entry "$selection"
    ;;
  *)
    exit 0
    ;;
  esac
done
