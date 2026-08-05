#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
lid-mode.sh — the "lid blanks the screen instead of suspending" mode (bind SUPER+SHIFT+A)

Commands:
  toggle    turn the mode on/off
  on|off    turn on/off explicitly
  close     lid-close handler (bindl switch:on:Lid Switch)
  open      lid-open handler (bindl switch:off:Lid Switch)
  status    print the current state (on|off) — for scripts
  help      this help

How it works. Normally the lid is handled by logind (HandleLidSwitch=suspend) and
by default it IGNORES inhibitor locks on it (LidSwitchIgnoreInhibited=yes). On the
laptop that ignore is disabled (nixos/laptop/logind.nix), so the "mode" is just a
live systemd-inhibit --what=handle-lid-switch lock in the transient unit
huix-lid-inhibit: while it holds, logind doesn't touch the lid, and Hyprland via
the switch binds blanks only the internal panel through dpms — an external monitor,
if attached, keeps working

State is NOT stored in a file: the source of truth is whether the unit is active.
So the mode lives only within the session, and after a reboot/relogin the laptop
suspends on the lid again — deliberately, so you don't leave it enabled in a bag
EOF
}

UNIT="huix-lid-inhibit"
LOGIND_CONF="/etc/systemd/logind.conf"

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Lid mode error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

notify_info() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "$1" "$2" || true
}

is_on() {
  systemctl --user is-active --quiet "$UNIT.service"
}

# Blank only the internal panel: with an external monitor attached a closed lid
# shouldn't blank it too. If no internal output is found — blank everything
internal_monitor() {
  hyprctl monitors -j 2>/dev/null |
    jq -r 'map(select(.name | test("^(eDP|LVDS|DSI)"; "i"))) | .[0].name // empty' 2>/dev/null || true
}

dpms() {
  local mon
  mon="$(internal_monitor)"
  hyprctl dispatch dpms "$1" ${mon:+"$mon"} >/dev/null 2>&1 || true
}

# The lock is useless if the system still ignores lid inhibitors — usually this
# means the nixos-rebuild with nixos/laptop/logind.nix hasn't been applied yet
warn_if_inhibitor_ignored() {
  grep -qiE '^\s*LidSwitchIgnoreInhibited\s*=\s*(no|false|0)\s*$' "$LOGIND_CONF" 2>/dev/null && return 0
  notify_error "logind ignores lid locks: no LidSwitchIgnoreInhibited=no in $LOGIND_CONF (needs nixos-rebuild)"
}

cmd_on() {
  if ! is_on; then
    systemd-run --user --collect --quiet \
      --unit="$UNIT" \
      --description="huix: lid blanks the screen instead of suspending" \
      systemd-inhibit \
      --what=handle-lid-switch \
      --mode=block \
      --who="huix lid-mode" \
      --why="a closed lid only blanks the screen" \
      sleep infinity || true

    # systemd-run returns immediately; wait until the unit actually comes up
    for _ in {1..20}; do
      is_on && break
      sleep 0.05
    done

    if ! is_on; then
      notify_error "Failed to take the handle-lid-switch lock ヽ(ﾟДﾟ)ﾉ"
      exit 1
    fi

    warn_if_inhibitor_ignored || true
  fi

  notify_info "Lid doesn't suspend (´∇ﾉ｀*)ノ" "Closing the lid only blanks the screen"
}

cmd_off() {
  systemctl --user stop "$UNIT.service" 2>/dev/null || true

  # Safety net: the mode may have been turned off from an external keyboard with the panel blanked
  dpms on

  notify_info "Lid suspends （-＾〇＾-）" "Normal behavior: closing the lid suspends"
}

cmd_close() {
  # Mode is off — do nothing, the lid is handled by logind (suspend)
  is_on || exit 0
  dpms off
}

cmd_status() {
  if is_on; then echo "on"; else echo "off"; fi
}

case "${1:-}" in
toggle)
  if is_on; then cmd_off; else cmd_on; fi
  ;;
on) cmd_on ;;
off) cmd_off ;;
close) cmd_close ;;
open) dpms on ;;
status) cmd_status ;;
help | -h | --help) usage ;;
*)
  usage >&2
  notify_error "Usage: lid-mode.sh toggle|on|off|close|open|status|help"
  exit 1
  ;;
esac
