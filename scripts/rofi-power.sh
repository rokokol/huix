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

# Both hyprland options that wake the monitor on any input
wake_on_input() {
  hyprctl --batch "keyword misc:key_press_enables_dpms $1; keyword misc:mouse_move_enables_dpms $1" >/dev/null
}

# hypridle has no "idle now" trigger (dbus gives only GetActive/Inhibit/UnInhibit), so the
# blanking is here; hyprland does the waking, muted for the half second in which the key
# release that dismissed rofi would land in the dark screen and undo it
screen_off() {
  trap 'wake_on_input true' EXIT
  wake_on_input false
  hyprctl dispatch dpms off >/dev/null
  sleep 0.5
}

# Outside rofi it's a launcher: mode "power", the emoji label comes from the rofi config
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show power -modi "power:$0" -mesg "What are we doing? (⊃‿⊂)"
fi

# On selection rofi puts the action in ROFI_INFO. An empty ROFI_INFO is the first
# call: print the items (visible label + hidden action in info)
case "${ROFI_INFO:-}" in
lock)      loginctl lock-session ;;
screenoff) screen_off & disown ;;
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
