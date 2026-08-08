#!/usr/bin/env bash

# mako notification feed in rofi (a script-modi, like the shader picker): a DND toggle,
# history clear, clicking a notification copies its text. All the logic is in
# notify-center.sh, this is only the presentation

set -euo pipefail

require_env() {
  if [[ -z "${HUIX:-}" ]]; then
    command -v notify-send >/dev/null 2>&1 &&
      notify-send -u critical "Notify center error (╯°□°）╯︵ ┻━┻" "HUIX is not set"
    exit 1
  fi
}

require_env

NC="$HUIX/scripts/notify-center.sh"

# List row width in characters: rofi can't wrap inside an item (single-line,
# truncated with …), so we wrap long text ourselves — like in rofi-wooordhunt.sh
WRAP_WIDTH=60

# Outside rofi it's a launcher: run rofi with this same script as the modi
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show notifications -modi "notifications:$0" -mesg "Notification center"
fi

# Main list. Notification rows carry the id in info, service rows carry a command
print_top() {
  local menu id icon label
  menu=$("$NC" menu)
  [[ -n "$menu" ]] && printf '🧹 Clear history (ﾉ>ω<)ﾉ ･ﾟ✧\0info\x1fcmd:clear\n'
  if [[ "$("$NC" dnd status)" == "on" ]]; then
    printf '🔔 Enable notifications ヽ(・∀・)ﾉ\0info\x1fcmd:dnd\n'
  else
    printf '🔕 Do not disturb (－ω－) zzZ\0info\x1fcmd:dnd\n'
  fi
  [[ -n "$menu" ]] || return 0
  # Separator \x1f, not TAB: whitespace-IFS collapses the empty icon field, and
  # label slides into icon (see cmd_menu in notify-center.sh)
  local first line
  while IFS=$'\x1f' read -r id icon label; do
    # The first line is the item itself, the tail are non-selectable continuation
    # lines with the same id: a stray Enter on them still copies the text
    first=1
    while IFS= read -r line; do
      if ((first)); then
        first=0
        if [[ -n "$icon" ]]; then
          printf '%s\0info\x1fid:%s\x1ficon\x1f%s\n' "$line" "$id" "$icon"
        else
          printf '%s\0info\x1fid:%s\n' "$line" "$id"
        fi
      else
        printf '   %s\0info\x1fid:%s\x1fnonselectable\x1ftrue\n' "$line" "$id"
      fi
    done < <(fold -s -w "$WRAP_WIDTH" <<<"$label")
  done <<<"$menu"
}

# Empty output closes rofi; printing a new list continues the session
case "${ROFI_INFO:-}" in
  "")        print_top ;;
  cmd:dnd)   "$NC" dnd toggle ;;
  cmd:clear) "$NC" clear ;;
  id:*)      "$NC" text "${ROFI_INFO#id:}" | wl-copy ;;
esac
