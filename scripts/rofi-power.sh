#!/usr/bin/env bash

# Power menu in rofi (script-modi "power"): lock, screen off, suspend, reboot,
# log out of the session, power off. Bound to the power key (XF86PowerOff) and
# to a bind in hyprland.conf. The mode emoji (⚡) is set in
# home-manager/programs/rofi.nix (display-power) — the single source of
# mode emojis, it isn't here. The logic is done by systemctl/loginctl/hyprctl

set -euo pipefail

# List items: "label|action". The action is a key from the case below
list_options() {
  cat <<'EOF'
🔒 Lock|lock
🌑 Screen off|screenoff
😴 Suspend|suspend
🔁 Reboot|reboot
🚪 Log out|logout
⏻ Power off|poweroff
EOF
}

# Blanks the monitor and waits for the cursor to move before turning it back on. Runs
# detached so the menu closes immediately instead of blocking on the wait
screen_off_until_move() {
  hyprctl dispatch dpms off
  local x0 y0 x y
  IFS=', ' read -r x0 y0 <<<"$(hyprctl cursorpos)"
  while IFS=', ' read -r x y <<<"$(hyprctl cursorpos)"; do
    [[ "$x" == "$x0" && "$y" == "$y0" ]] || break
    sleep 0.2
  done
  hyprctl dispatch dpms on
}

# Outside rofi it's a launcher: mode "power", the emoji label comes from the rofi config
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show power -modi "power:$0" -mesg "What are we doing? (⊃‿⊂)"
fi

# On selection rofi puts the action in ROFI_INFO. An empty ROFI_INFO is the first
# call: print the items (visible label + hidden action in info)
case "${ROFI_INFO:-}" in
lock)      loginctl lock-session ;;
screenoff) screen_off_until_move & disown ;;
suspend)   systemctl suspend ;;
reboot)    systemctl reboot ;;
logout)    hyprctl dispatch exit ;;
poweroff)  systemctl poweroff ;;
"")
  while IFS='|' read -r label action; do
    printf '%s\0info\x1f%s\n' "$label" "$action"
  done < <(list_options)
  ;;
esac
