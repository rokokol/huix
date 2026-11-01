#!/usr/bin/env bash
# The laptop's touchscreen is what the touch gestures and tablet mode are for, and it also
# reports contacts with no coordinates at all when nothing touches it; Hyprland warps the
# pointer to the stale position for each of them, and follow_mouse takes the focus along, so
# the window under the pointer starts receiving the typing. This switch turns the device off
# and on by hand, and `apply` puts the choice back after a config reload, which re-enables
# every device. The pen is a device of its own and keeps working

set -euo pipefail

usage() {
  cat <<'EOF'
touchscreen.sh — the built-in touchscreen off, and back on (bind SUPER+SHIFT+T)

Commands:
  toggle    turn the touchscreen off, or back on
  on|off    turn it on or off explicitly
  apply     re-apply the remembered state (the compositor's start and config reload)
  status    print the current state (on|off) — for scripts
  help      this help

The choice outlives a config reload and a new session: Hyprland re-enables every input
device on a reload, so it is kept in $XDG_STATE_HOME/huix/touchscreen and put back by
`apply`. Off takes the touch gestures with it — the compositor sees no touch at all
EOF
}

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/huix/touchscreen"

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Touchscreen error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

notify_info() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "$1" "$2" || true
}

fail() {
  notify_error "$1"
  exit 1
}

# The compositor's own name for the device: it is the kernel's, spelled Hyprland's way, and
# a ruleset that renamed the device would move it, so it is read back rather than written
# here. The one touchscreen is the first of the touch devices
touch_name() {
  hyprctl devices -j 2>/dev/null | jq -r '.touch[0].name // empty' 2>/dev/null || true
}

save() {
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$1" >"$STATE_FILE"
}

saved() {
  if [[ -r "$STATE_FILE" ]]; then cat "$STATE_FILE"; else printf 'on\n'; fi
}

# Hyprland applies the flag but answers nothing about it, so the file is the source of truth
# both for `status` and for what `toggle` flips. A quiet call says nothing about a device
# that is not there yet, which is what the compositor's own start can do
set_enabled() {
  local name
  name=$(touch_name)
  if [[ -z "$name" ]]; then
    if [[ "${2:-}" == quiet ]]; then return 0; fi
    fail "No touchscreen: hyprctl devices names none"
  fi
  hyprctl eval "hl.device({ name = \"$name\", enabled = $1 })" >/dev/null
}

cmd_on() {
  set_enabled true
  save on
  notify_info "Touchscreen on (´∇ﾉ｀*)ノ" "Taps and touch gestures work again"
}

cmd_off() {
  set_enabled false
  save off
  notify_info "Touchscreen off (－_－) zzZ" "Taps and touch gestures stop; the pen still draws"
}

cmd_toggle() {
  if [[ "$(saved)" == off ]]; then cmd_on; else cmd_off; fi
}

cmd_apply() {
  [[ -r "$STATE_FILE" ]] || exit 0
  if [[ "$(saved)" == off ]]; then set_enabled false quiet; else set_enabled true quiet; fi
}

case "${1:-}" in
  toggle) cmd_toggle ;;
  on) cmd_on ;;
  off) cmd_off ;;
  apply) cmd_apply ;;
  status) saved ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    notify_error "Usage: touchscreen.sh toggle|on|off|apply|status|help"
    exit 2
    ;;
esac
