#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
rofi-clipboard.sh — pick an entry of the clipboard history in rofi and copy it back

  rofi-clipboard.sh          open the history in rofi and copy the entry chosen
  rofi-clipboard.sh help     this text

The history comes from cliphist, and an image entry shows its preview. Return copies the
entry, Control+Return copies the typed text as it is, Delete removes the entry, and Escape
leaves the clipboard as it was
EOF
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

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

# rofi prints "INDEX TEXT": a history entry comes with its row index, while the typed text
# (Control+Return, or Return when nothing matches) comes with index -1
while true; do
  if selection=$(
    build_menu | rofi \
      -dmenu \
      -i \
      -show-icons \
      -display-columns 2 \
      -format 'i s' \
      \
      -p "📋" \
      \
      -kb-remove-char-forward "Delete" \
      -kb-accept-custom "Control+Return" \
      -kb-custom-1 "Control+d"
  ); then
    status=0
  else
    status=$?
  fi

  index="${selection%% *}"
  text="${selection#* }"

  case "$status" in
    0)
      if [[ "$index" == -1 ]]; then
        [[ -n "$text" ]] || exit 0
        wl-copy -- "$text"
      else
        printf '%s\n' "$text" | cliphist decode | wl-copy
      fi
      exit 0
      ;;
    1)
      exit 0
      ;;
    10)
      [[ -n "$index" && "$index" != -1 ]] || continue
      delete_entry "$text"
      ;;
    *)
      exit 0
      ;;
  esac
done
