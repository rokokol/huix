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
  nav up|down         листать ленту в тултипе waybar (колесо по индикатору)
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
# висящее на экране уведомление невидимым для счётчика. Тултип: последние 5
# записей, при живом nav-курсоре — страница вокруг него с маркером ▶.
cmd_status() {
  local dnd=0
  dnd_active && dnd=1
  load_nav
  feed_json | jq -c --argjson dnd "$dnd" --argjson idx "$idx" '
    . as $all
    | ($all | length) as $n
    | ($all | map(
        ("\(.app_name // "?"): \(.summary // "")"
         + (if (.body // "") != "" then
              " — " + (.body | gsub("\\s+"; " ") | .[0:80])
            else "" end))
        | @html)) as $lines
    | (if $n == 0 then "Уведомлений нет ( ´ ▽ ` )"
       elif $idx >= 0 then
         ([$idx, $n - 1] | min) as $cur
         | ([$cur - 2, 0] | max) as $from
         | ([$from + 9, $n] | min) as $to
         | ("📜 \($cur + 1)/\($n)\n"
            + ([range($from; $to)
                | if . == $cur then "<b>▶ \($lines[.])</b>" else "   \($lines[.])" end]
               | join("\n")))
       else $lines[:5] | join("\n") end) as $feed
    | $feed as $tt
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
      ((if .urgency == "critical" then "🔴" elif .urgency == "low" then "🟢" else "🟡" end)
       + " \(.app_name // "?"): \((.summary // "") | gsub("[\\t\\n\\u001f]"; " "))"
       + (if (.body // "") != "" then
            " — " + (.body | gsub("[\\t\\n\\u001f]"; " ") | .[0:70])
          else "" end))
    ] | join("")'
}

cmd_text() {
  local id="${1:?id required}"
  feed_json | jq -r --argjson id "$id" '
    .[] | select(.id == $id)
    | [(.summary // ""), (.body // "")] | map(select(. != "")) | join("\n")'
}

# Курсор листания эфемерный: живёт в рантайме и протухает через NAV_TTL секунд
# без скролла — тултип возвращается к обычной сводке.
NAV_STATE="${XDG_RUNTIME_DIR:-/tmp}/huix-notify-nav"
NAV_TTL=20

feed_json() {
  {
    makoctl list -j
    makoctl history -j
  } | jq -s '.[0] + .[1]'
}

feed_len() {
  feed_json | jq length
}

load_nav() { # -> глобальный idx: позиция курсора в ленте, -1 = неактивен
  idx=-1
  local ts=0 now
  now=$(date +%s)
  if [[ -f "$NAV_STATE" ]]; then
    # shellcheck disable=SC1090
    source "$NAV_STATE"
    [[ "$idx" =~ ^-?[0-9]+$ ]] || idx=-1
    # NB: не сворачивать в `(( )) && ...` — ложное (( )) последней командой
    # функции вернёт 1, и set -e убьёт скрипт.
    if ((now - ts > NAV_TTL)); then idx=-1; fi
  fi
}

cmd_nav() {
  local dir="${1:?up|down required}" n
  load_nav
  n=$(feed_len)
  # down — глубже (старее), up — к свежим; первый скролл встаёт на самую свежую.
  case "$dir" in
  down)
    idx=$((idx + 1))
    ((idx > n - 1)) && idx=$((n - 1))
    ;;
  up)
    idx=$((idx - 1))
    ((idx < 0)) && idx=0
    ;;
  *)
    notify_error "Usage: nav up|down"
    exit 1
    ;;
  esac
  ((n == 0)) && idx=-1
  printf 'idx=%s\nts=%s\n' "$idx" "$(date +%s)" >"$NAV_STATE"
  signal_waybar
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
nav)
  shift
  cmd_nav "$@"
  ;;
help | -h | --help) usage ;;
*)
  usage >&2
  notify_error "Usage: notify-center.sh status|dnd|clear|menu|text|nav|help"
  exit 1
  ;;
esac
