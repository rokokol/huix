#!/usr/bin/env bash
# The mode is two user units, huix-auto-rotate and huix-virt-keyboard, declared in
# home-manager/desktop/hyprland/services/tablet-mode.nix; whether the first one is active is
# the state, and nothing is stored in a file. The titlebars and the hidden cursor are
# config options, which a Hyprland reload resets together with the monitor transform, so
# sync runs on every reload and re-applies them. The bar's keyboard button doubles as the
# mode indicator, so a change pokes waybar instead of sending a notification
# Needs systemctl, hyprctl, evtest, pgrep and pkill
set -euo pipefail

usage() {
  cat <<'EOF'
tablet-mode.sh — the folded-laptop mode: auto-rotation, titlebars, no cursor, on-screen keyboard

  tablet-mode.sh on                                 enter the mode
  tablet-mode.sh off                                leave it
  tablet-mode.sh toggle                             one or the other
  tablet-mode.sh sync                               follow the tablet-mode switch
  tablet-mode.sh status                             print on or off
  tablet-mode.sh virt-keyboard toggle|show|hide     the on-screen keyboard, in either mode
  tablet-mode.sh virt-keyboard status               the bar button as waybar JSON: the
                                                    keyboard glyph in the mode, nothing outside it

sync is for the start of the session and every Hyprland reload: switch binds fire only on
a change, and a reload resets the transform and the titlebars to the config
Environment: HUIX_TABLET_SWITCH names the switch device sync reads (as hyprctl devices
prints it); HUIX_INPUT_DEVICES is where the kernel lists input devices (default
/proc/bus/input/devices); HUIX_TABLET_SIGNAL is the N of the SIGRTMIN+N waybar refreshes
the button on, unset when no bar shows one
Nothing here reaches the network
Exit 0 done, 1 when a unit, the switch or the keyboard cannot be reached, 2 on a usage error
EOF
}

fail() { # the thing asked about is wrong
  printf 'tablet-mode.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'tablet-mode.sh: %s\n' "$1" >&2
  exit 2
}

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

ROTATE_UNIT=huix-auto-rotate.service
OSK_UNIT=huix-virt-keyboard.service
OSK_PROCESS=wvkbd-mobintl

# waybar re-reads the button on the RT signal the bar declared; no bar, no signal. The
# process is .waybar-wrapped, so the name is matched as a substring, never exactly
signal_bar() {
  [ -n "${HUIX_TABLET_SIGNAL:-}" ] || return 0
  pkill "-RTMIN+$HUIX_TABLET_SIGNAL" waybar || true
}

is_on() {
  systemctl --user is-active --quiet "$ROTATE_UNIT"
}

osk_running() {
  systemctl --user is-active --quiet "$OSK_UNIT"
}

# The plugin is loaded on the laptop only; elsewhere the option is unknown and that is fine
titlebars() {
  hyprctl eval "hl.config({ plugin = { hyprbars = { enabled = $1 } } })" >/dev/null 2>&1 || true
}

# A finger needs no cursor, and hide_on_touch alone does not hold: the gesture plugin warps
# the pointer to every touch, which shows the cursor again
cursor_hidden() {
  hyprctl eval "hl.config({ cursor = { invisible = $1 } })" >/dev/null
}

enter() {
  systemctl --user start "$ROTATE_UNIT" "$OSK_UNIT" || fail "the tablet-mode units did not start"
  titlebars true
  cursor_hidden true
  signal_bar
}

leave() {
  systemctl --user stop "$ROTATE_UNIT" "$OSK_UNIT" || fail "the tablet-mode units did not stop"
  titlebars false
  cursor_hidden false
  bash "$HERE/rotate-screen.sh" set 0
  signal_bar
}

cmd_toggle() {
  if is_on; then leave; else enter; fi
}

# The event node of the switch, by the name the kernel gives it
switch_device() {
  awk -v name="$HUIX_TABLET_SWITCH" '
    $0 == ("N: Name=\"" name "\"") { found = 1; next }
    found && /^H: Handlers=/ {
      for (i = 2; i <= NF; i++) {
        handler = $i
        sub(/^Handlers=/, "", handler)
        if (handler ~ /^event[0-9]+$/) { print "/dev/input/" handler; exit }
      }
    }
  ' "${HUIX_INPUT_DEVICES:-/proc/bus/input/devices}"
}

cmd_sync() {
  local device status=0
  [ -n "${HUIX_TABLET_SWITCH:-}" ] || fail "HUIX_TABLET_SWITCH is not set"
  device=$(switch_device)
  [ -n "$device" ] || fail "no input device named $HUIX_TABLET_SWITCH"
  # evtest answers 10 when the switch is on, 0 when off
  evtest --query "$device" EV_SW SW_TABLET_MODE || status=$?
  case "$status" in
    10)
      if is_on; then
        # The sensor reports only changes; a restart makes it state the orientation again
        systemctl --user restart "$ROTATE_UNIT"
        titlebars true
        cursor_hidden true
      else
        enter
      fi
      ;;
    0) ! is_on || leave ;;
    *) fail "evtest could not read $device (status $status)" ;;
  esac
}

cmd_status() {
  if is_on; then printf 'on\n'; else printf 'off\n'; fi
}

osk_start() {
  local i
  systemctl --user start "$OSK_UNIT" || fail "the keyboard unit did not start"
  for i in 1 2 3 4 5 6 7 8 9 10; do
    pgrep -x "$OSK_PROCESS" >/dev/null && return 0
    sleep 0.2
  done
  fail "the keyboard did not come up"
}

# The keyboard starts hidden; SIGUSR1 hides, SIGUSR2 shows, SIGRTMIN toggles
cmd_virt_keyboard() {
  (($# == 1)) || die "virt-keyboard needs toggle, show, hide or status"
  case "$1" in
    status)
      # An empty text makes waybar hide the module, so outside the mode there is no button
      if is_on; then
        printf '{"text":"⌨️","class":"on"}\n'
      else
        printf '{"text":"","class":"off"}\n'
      fi
      ;;
    toggle)
      if osk_running; then
        pkill -RTMIN -x "$OSK_PROCESS"
      else
        osk_start
        pkill -USR2 -x "$OSK_PROCESS"
      fi
      ;;
    show)
      osk_running || osk_start
      pkill -USR2 -x "$OSK_PROCESS"
      ;;
    hide) ! osk_running || pkill -USR1 -x "$OSK_PROCESS" ;;
    *) die "virt-keyboard needs toggle, show, hide or status, not $1" ;;
  esac
}

cmd="${1:-}"
(($# == 0)) || shift
case "$cmd" in
  on) enter "$@" ;;
  off) leave "$@" ;;
  toggle) cmd_toggle "$@" ;;
  sync) cmd_sync "$@" ;;
  status) cmd_status "$@" ;;
  virt-keyboard) cmd_virt_keyboard "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'tablet-mode.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
