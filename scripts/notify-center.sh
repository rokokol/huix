#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
notify-center.sh — центр уведомлений поверх mako (=^･ω･^=)

Команды:
  status              JSON для waybar (custom/notifications)
  dnd toggle|on|off   переключить "не беспокоить"
  dnd status          печатает on|off
  clear               очистить всю историю
  menu                строки "id<US>icon<US>label" для rofi (новые сверху)
  text <id>           текст уведомления (для копирования)
  help                эта справка

Лента = видимые попапы + история mako, новые сверху, ничего не отсеивается.
Единственная операция над записью — скопировать текст; действия (кнопки)
уведомлений доступны нативно и только у видимых попапов: ЛКМ — default
action, ПКМ — makoctl menu. История чистится только целиком.

DND — родной механизм mako: режим do-not-disturb с invisible=1 (man mako(5)).
Скрипт лишь дёргает makoctl mode и пинает waybar сигналом, чтобы индикатор
обновился сразу. Режимы живут в рантайме демона: DND переживает reload
Hyprland и nixos-rebuild, но сбрасывается с перезапуском сессии.

У makoctl нет команды очистки истории, поэтому clear — restore+dismiss
каждой записи под невидимым режимом silent (см. mako.nix), чтобы попапы
не мигали на экране.
EOF
}

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Notify center error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

# Номер SIGRTMIN+N задаёт Nix (waybar/notifications.nix) через
# WAYBAR_NOTIF_SIGNAL. Гонки с автостартом waybar нет: сигнал шлётся только
# по явным действиям пользователя, когда waybar уже жив.
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

# Счётчик считает ленту целиком — история без видимых попапов сделала бы
# висящее на экране уведомление невидимым для счётчика. Тултип — последние
# 5 записей.
cmd_status() {
  local dnd=0
  dnd_active && dnd=1
  feed_json | jq -c --argjson dnd "$dnd" '
    . as $all
    | ($all | length) as $n
    | (if $n == 0 then "Уведомлений нет ( ´ ▽ ` )"
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
         tooltip: ("Не беспокоить (－ω－) zzZ\n" + $tt), class: "dnd"}
      elif $n > 0 then
        {text: "🔔 \($n)", tooltip: $tt, class: "history"}
      else
        {text: "🔔", tooltip: $tt, class: "empty"}
      end'
}

# Разделитель полей — именно \x1f, НЕ таб: у записей без иконки среднее поле
# пустое, а TAB — IFS-whitespace, bash схлопывает подряд идущие whitespace-
# разделители и теряет пустые поля. Сам \x1f из текста вычищаем.
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
  # restore всегда снимает верхушку истории — идём по снимку ids сверху вниз.
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
