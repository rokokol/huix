#!/usr/bin/env bash
# The mode is two user units, huix-auto-rotate and huix-virt-keyboard, declared in
# home-manager/desktop/hyprland/services/tablet-mode.nix; whether the first one is active is
# the state, and the rotation lock is the only state a file keeps. The titlebars and the
# hidden cursor are config options, which a Hyprland reload resets together with the
# monitor transform, so sync runs on every reload and re-applies them. The bar's keyboard button doubles as the
# mode indicator, so a change pokes waybar instead of sending a notification. The lock
# key has no button to answer with, so a hold or release rides out as one low note
# Needs systemctl, hyprctl, evtest, pgrep, pkill and notify-send
set -euo pipefail

usage() {
  cat <<'EOF'
tablet-mode.sh — the folded-laptop mode: auto-rotation, titlebars, no cursor, on-screen keyboard

  tablet-mode.sh on                                 enter the mode
  tablet-mode.sh off                                leave it
  tablet-mode.sh toggle                             one or the other
  tablet-mode.sh lock on|off|toggle                 hold or release the screen's orientation
  tablet-mode.sh lock status                        print on or off
  tablet-mode.sh sync                               follow the tablet-mode switch
  tablet-mode.sh status                             print on or off
  tablet-mode.sh virt-keyboard toggle|show|hide     the on-screen keyboard, in either mode
  tablet-mode.sh virt-keyboard status               the bar button as waybar JSON: the
                                                    keyboard glyph in the mode, nothing outside it

sync is for the start of the session and every Hyprland reload: switch binds fire only on
a change, and a reload resets the transform and the titlebars to the config. Every hold
and release of the rotation lock pops one low-urgency note about what the screen does now
Environment: HUIX_TABLET_SWITCH names the switch device sync reads (as hyprctl devices
prints it); HUIX_INPUT_DEVICES is where the kernel lists input devices (default
/proc/bus/input/devices); HUIX_TABLET_SIGNAL is the N of the SIGRTMIN+N waybar refreshes
the button on, unset when no bar shows one; HUIX_ROTATION_LOCK is where the rotation lock
file lives (default $XDG_RUNTIME_DIR/huix-rotation-lock)
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

# The bar button carries the mode, but the lock key speaks to its owner on its own; a
# missing notifier drops the note, as no one is looking
notify() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "$1" "$2" || true
}

is_on() {
  systemctl --user is-active --quiet "$ROTATE_UNIT"
}

osk_running() {
  systemctl --user is-active --quiet "$OSK_UNIT"
}

# The lock is one file in the runtime directory: it holds through a reload and through
# the switch, and it is gone when the mode is unlocked or the session ends
lock_file() {
  printf '%s\n' "${HUIX_ROTATION_LOCK:-${XDG_RUNTIME_DIR:-/tmp}/huix-rotation-lock}"
}

is_locked() {
  [ -e "$(lock_file)" ]
}

# Holding the screen means the rotation stops where it is, and nothing below turns it
# again: not the switch, not a reload, not leaving the mode, which no longer puts the
# screen upright while the file is there
hold_rotation() {
  mkdir -p "$(dirname "$(lock_file)")"
  : >"$(lock_file)"
  if systemctl --user is-active --quiet "$ROTATE_UNIT"; then
    systemctl --user stop "$ROTATE_UNIT" || fail "the auto-rotate unit did not stop"
  fi
  notify "Rotation held ┬─┬ ノ( ゜-゜ノ)" "The screen keeps this orientation until the key lets it go"
}

# Releasing hands the rotation back to the switch: on, it resumes; off or unknown, it
# waits for the next time the mode starts or sync restarts the unit. A fresh unit states
# the orientation the sensor already has, so a start needs no restart beside it
release_rotation() {
  local status=0 device
  rm -f "$(lock_file)"
  [ -n "${HUIX_TABLET_SWITCH:-}" ] || return 0
  device=$(switch_device)
  [ -n "$device" ] || return 0
  evtest --query "$device" EV_SW SW_TABLET_MODE || status=$?
  case "$status" in
    10) systemctl --user is-active --quiet "$ROTATE_UNIT" ||
      systemctl --user start "$ROTATE_UNIT" ||
      fail "the auto-rotate unit did not start"
      notify "Rotation released (╯°□°）╯︵ ┻━┻" "The screen turns with the sensor again" ;;
    0)
      notify "Rotation released (╯°□°）╯︵ ┻━┻" "The screen turns when the laptop is folded"
      ;;
    *) fail "evtest could not read $device (status $status)" ;;
  esac
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
  # The lock holds into the mode: without it the rotation starts beside the keyboard
  if is_locked; then
    systemctl --user start "$OSK_UNIT" || fail "the tablet-mode units did not start"
  else
    systemctl --user start "$ROTATE_UNIT" "$OSK_UNIT" || fail "the tablet-mode units did not start"
  fi
  titlebars true
  cursor_hidden true
  signal_bar
}

leave() {
  systemctl --user stop "$ROTATE_UNIT" "$OSK_UNIT" || fail "the tablet-mode units did not stop"
  titlebars false
  cursor_hidden false
  # Under the lock the orientation is the screen's own: upright is for an unlocked mode
  if ! is_locked; then
    bash "$HERE/rotate-screen.sh" set 0
  fi
  signal_bar
}

cmd_toggle() {
  if is_on; then leave; else enter; fi
}

cmd_lock() {
  (($# == 1)) || die "lock needs on, off, toggle or status"
  case "$1" in
    on) hold_rotation ;;
    off) release_rotation ;;
    toggle) if is_locked; then release_rotation; else hold_rotation; fi ;;
    status) is_locked && printf 'on\n' || printf 'off\n' ;;
    *) die "lock needs on, off, toggle or status, not $1" ;;
  esac
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
        if is_locked; then
          # Under the lock the rotation stays stopped: a reload brings the looks back
          # alone, never a restart of the unit
          titlebars true
          cursor_hidden true
        else
          # The sensor reports only changes; a restart makes it state the orientation again
          systemctl --user restart "$ROTATE_UNIT"
          titlebars true
          cursor_hidden true
        fi
      else
        # The lock decides with enter whether the rotation starts beside the keyboard
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
  systemctl --user start "$OSK_UNIT" || fail "the keyboard unit did not start"
  for _ in 1 2 3 4 5 6 7 8 9 10; do
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
      # An empty text makes waybar hide the module, so outside the mode there is no button.
      # The keyboard unit alone also answers to it: under the lock the rotation unit is
      # stopped while the mode is on, and the button must stay to toggle the keyboard with
      if is_on || osk_running; then
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
  lock) cmd_lock "$@" ;;
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
