#!/usr/bin/env bash

set -euo pipefail

require_env() {
  if [[ -z "${HUIX:-}" ]]; then
    command -v notify-send >/dev/null 2>&1 &&
      notify-send -u critical "Shader error (╯°□°）╯︵ ┻━┻" "HUIX is not set"
    exit 1
  fi
}

require_env

# Outside rofi it's a launcher: run rofi with this same script as the "shader" modi
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show shader -modi "shader:$0" -mesg "Full-screen effect"
fi

SS="$HUIX/scripts/screen-shader.sh"

# Service values of the brightness buttons (not effects) — handled separately
BRIGHT_UP="__bright_up__"
BRIGHT_DOWN="__bright_down__"

# Selection via ROFI_INFO: brightness buttons adjust soft brightness; effects toggle in/out of the stack
# No exec — reprint the list so rofi stays open; "Normal" clears all, Escape closes
if [[ -n "${ROFI_INFO:-}" ]]; then
  case "$ROFI_INFO" in
  "$BRIGHT_UP") "$SS" bright up ;;
  "$BRIGHT_DOWN") "$SS" bright down ;;
  *) "$SS" effect toggle "$ROFI_INFO" ;;
  esac
fi

# keep-selection: after applying an item rofi redraws the list — without this the
# cursor would jump to the top. With the option the position is kept, so you can
# click effects/brightness in a row without scrolling again (rofi >= 1.7; here 2.0)
printf '\0keep-selection\x1ftrue\n'
# The current soft-brightness level goes into the message above the list, updated on every click
printf '\0message\x1fFull-screen effect · brightness %s%%\n' "$("$SS" bright get)"

# Print the effects: visible label + hidden value (info). Active ones are marked
# with an apply number (01. 02. …) — see cmd_menu in screen-shader.sh. Right after
# "Normal" (reset) we insert the soft-brightness buttons — different emojis
# (☀️ brighter / 🌑 darker) for clarity; together with keep-selection it's handy to press in a row
while IFS='|' read -r label value; do
  printf '%s\0info\x1f%s\n' "$label" "$value"
  if [[ "$value" == "none" ]]; then
    printf '🌕 Brightness +\0info\x1f%s\n' "$BRIGHT_UP"
    printf '🌑 Brightness −\0info\x1f%s\n' "$BRIGHT_DOWN"
  fi
done < <("$SS" menu)
