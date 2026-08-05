#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
notify-center.sh — notification center on top of mako (=^･ω･^=)

Commands:
  status              JSON for waybar (custom/notifications)
  dnd toggle|on|off   toggle "do not disturb"
  dnd status          prints on|off
  clear               clear the whole history
  menu                "id<US>icon<US>label" lines for rofi (newest on top)
  text <id>           notification text (for copying)
  help                this help

The feed = visible popups + mako history, newest on top, nothing is filtered out.
The only operation on an entry is copying the text; notification actions (buttons)
are available natively and only on visible popups: LMB — default action, RMB —
makoctl menu. History is cleared only as a whole.

DND is mako's native mechanism: the do-not-disturb mode with invisible=1 (man
mako(5)). The script just pokes makoctl mode and kicks waybar with a signal so the
indicator refreshes at once. Modes live in the daemon's runtime: DND survives a
Hyprland reload and nixos-rebuild, but resets when the session restarts.

makoctl has no history-clear command, so clear is a restore+dismiss of each entry
under the invisible silent mode (see mako.nix) so popups don't flash on screen.
EOF
}

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Notify center error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

# The SIGRTMIN+N number is set by Nix (waybar/notifications.nix) via
# WAYBAR_NOTIF_SIGNAL. There's no race with waybar autostart: the signal is sent
# only on explicit user actions, when waybar is already alive.
signal_waybar() {
  [[ -n "${WAYBAR_NOTIF_SIGNAL:-}" ]] || return 0
  pkill -RTMIN+"$WAYBAR_NOTIF_SIGNAL" waybar 2>/dev/null || true
}

dnd_active() {
  makoctl mode | grep -qx do-not-disturb
}

cmd_dnd() {
  case "${1:-}" in
  on) makoctl mode -a do-not-disturb >/dev/null ;;
  off) makoctl mode -r do-not-disturb >/dev/null ;;
  toggle) makoctl mode -t do-not-disturb >/dev/null ;;
  status)
    if dnd_active; then printf 'on\n'; else printf 'off\n'; fi
    return
    ;;
  *)
    notify_error "Usage: dnd toggle|on|off|status"
    exit 1
    ;;
  esac
  signal_waybar
}

# The counter counts the whole feed — history without visible popups would make a
# notification hanging on screen invisible to the counter. Tooltip = the last
# 5 entries.
cmd_status() {
  local dnd=0
  dnd_active && dnd=1
  feed_json | jq -c --argjson dnd "$dnd" '
    . as $all
    | ($all | length) as $n
    | (if $n == 0 then "No notifications ( ´ ▽ ` )"
       else
         $all[:5] | map(
           ("\(.app_name // "?"): \(.summary // "")"
            + (if (.body // "") != "" then
                 " — " + (.body | gsub("\\s+"; " ") | .[0:80])
               else "" end))
           | @html) | join("\n")
       end) as $tt
    | if $dnd == 1 then
        {text: (if $n > 0 then "🔕 \($n)" else "🔕" end),
         tooltip: ("Do not disturb (－ω－) zzZ\n" + $tt), class: "dnd"}
      elif $n > 0 then
        {text: "🔔 \($n)", tooltip: $tt, class: "history"}
      else
        {text: "🔔", tooltip: $tt, class: "empty"}
      end'
}

# The field separator is exactly \x1f, NOT a tab: entries without an icon have an
# empty middle field, and TAB is IFS-whitespace, so bash collapses consecutive
# whitespace separators and loses empty fields. We strip \x1f from the text itself.
cmd_menu() {
  feed_json | jq -r '
    .[] | [
      (.id | tostring),
      (.app_icon // ""),
      ((if .urgency == "critical" then "🔴" elif .urgency == "normal" then "🟡" elif .urgency == "low" then "🟢" else "⚪" end)
       + " \(.app_name // "?"): \((.summary // "") | gsub("[\\t\\n]"; " "))"
       + (if (.body // "") != "" then
            " — " + (.body | gsub("[\\t\\n]"; " ") | .[0:200])
          else "" end))
    ] | join("")'
}

cmd_text() {
  local id="${1:?id required}"
  feed_json | jq -r --argjson id "$id" '
    .[] | select(.id == $id)
    | [(.summary // ""), (.body // "")] | map(select(. != "")) | join("\n")'
}

feed_json() {
  {
    makoctl list -j
    makoctl history -j
  } | jq -s add
}

silent_on() { makoctl mode -a silent >/dev/null; }
silent_off() { makoctl mode -r silent >/dev/null 2>&1 || true; }

cmd_clear() {
  trap silent_off EXIT
  local id
  silent_on
  # restore always takes the top of the history — iterate over the ids snapshot top-down
  while read -r id; do
    makoctl restore
    makoctl dismiss -n "$id" -h
  done < <(makoctl history -j | jq -r '.[].id')
  silent_off
  signal_waybar
}

case "${1:-}" in
status) cmd_status ;;
dnd)
  shift
  cmd_dnd "$@"
  ;;
clear) cmd_clear ;;
menu) cmd_menu ;;
text)
  shift
  cmd_text "$@"
  ;;
help | -h | --help) usage ;;
*)
  usage >&2
  notify_error "Usage: notify-center.sh status|dnd|clear|menu|text|help"
  exit 1
  ;;
esac
