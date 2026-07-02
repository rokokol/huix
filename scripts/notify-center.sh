#!/usr/bin/env bash

# Центр уведомлений поверх mako: режим "не беспокоить", история, waybar-индикатор.
#
# У mako нет команд "удалить одно уведомление из истории" и "показать снова
# произвольное" — есть только restore (возвращает на экран САМОЕ СВЕЖЕЕ из
# истории) и dismiss [-h|--no-history]. Поэтому обе операции сделаны цепочкой:
# под служебным невидимым режимом (mode=silent, см. mako.nix) restore-им записи
# с верхушки истории до целевой, делаем своё дело и возвращаем лишние обратно
# повторным dismiss — он кладёт их в историю сверху, так что порядок
# сохраняется, если возвращать от старых к новым. Попапы при этом не мигают.
#
# Вызвать action у уведомления ИЗ ИСТОРИИ mako не умеет (makoctl invoke молча
# возвращает 0, но действие не доставляется — проверено), поэтому
# "взаимодействие" = restore: уведомление возвращается на экран живым, со
# своими кнопками/меню (ПКМ по попапу — makoctl menu, как обычно).
#
# Режимы mako живут в рантайме демона: DND переживает reload Hyprland и
# nixos-rebuild, но сбрасывается при перезапуске сессии — для "временно
# отключить" это ожидаемое поведение, restore-на-старте не нужен.
#
# Использование:
#   notify-center.sh status          — JSON для waybar (custom/notifications)
#   notify-center.sh dnd toggle|on|off — переключить "не беспокоить"
#   notify-center.sh dnd status      — печатает on|off (для rofi-notify.sh)
#   notify-center.sh clear           — очистить всю историю
#   notify-center.sh delete <id>     — убрать одну запись из истории
#   notify-center.sh restore <id>    — показать уведомление из истории снова
#   notify-center.sh menu            — строки "id<TAB>icon<TAB>label" для rofi
#   notify-center.sh text <id>       — текст уведомления (для копирования)

set -euo pipefail

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Notify center error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

# Пинаем waybar перечитать индикатор (модуль слушает SIGRTMIN+N). Номер сигнала
# задаёт Nix (waybar-notifications.nix) и кладёт в WAYBAR_NOTIF_SIGNAL — единый
# источник правды. В отличие от шейдера, гонки с автостартом waybar тут нет:
# сигнал шлётся только по явным действиям пользователя, когда waybar уже жив.
signal_waybar() {
  [[ -n "${WAYBAR_NOTIF_SIGNAL:-}" ]] || return 0
  pkill -RTMIN+"$WAYBAR_NOTIF_SIGNAL" waybar 2>/dev/null || true
}

dnd_active() {
  makoctl mode | grep -qx do-not-disturb
}

cmd_dnd() {
  case "${1:-}" in
    on)     makoctl mode -a do-not-disturb >/dev/null ;;
    off)    makoctl mode -r do-not-disturb >/dev/null ;;
    toggle) makoctl mode -t do-not-disturb >/dev/null ;;
    status)
      if dnd_active; then printf 'on\n'; else printf 'off\n'; fi
      return
      ;;
    *) notify_error "Usage: dnd toggle|on|off|status"; exit 1 ;;
  esac
  signal_waybar
}

# JSON для waybar: колокольчик + счётчик истории, класс dnd при "не беспокоить",
# в тултипе — последние 5 уведомлений (текст экранируем: тултип — Pango-разметка).
cmd_status() {
  local dnd=0
  dnd_active && dnd=1
  makoctl history -j | jq -c --argjson dnd "$dnd" '
    length as $n
    | (if $n == 0 then "Уведомлений нет ( ´ ▽ ` )"
       else [.[:5][]
             | "\(.app_name // "?"): \(.summary // "")"
               + (if (.body // "") != "" then
                    " — " + (.body | gsub("\\s+"; " ") | .[0:80])
                  else "" end)]
            | join("\n") | @html
       end) as $hist
    | ($hist + "\nЛКМ: история · ПКМ: не беспокоить · СКМ: закрыть попапы") as $tt
    | if $dnd == 1 then
        {text: (if $n > 0 then "🔕 \($n)" else "🔕" end),
         tooltip: ("Не беспокоить (－ω－) zzZ\n" + $tt), class: "dnd"}
      elif $n > 0 then
        {text: "🔔 \($n)", tooltip: $tt, class: "history"}
      else
        {text: "🔔", tooltip: $tt, class: "empty"}
      end'
}

# Строки истории для rofi-пикера (rofi-notify.sh), новые сверху:
#   id<TAB>icon<TAB>label
# Табы и переводы строк внутри текста заменяем пробелами — TAB здесь разделитель.
cmd_menu() {
  makoctl history -j | jq -r '
    .[] | [
      (.id | tostring),
      (.app_icon // ""),
      ((if .urgency == "critical" then "🔴" elif .urgency == "low" then "🟢" else "🟡" end)
       + " \(.app_name // "?"): \((.summary // "") | gsub("[\\t\\n]"; " "))"
       + (if (.body // "") != "" then
            " — " + (.body | gsub("[\\t\\n]"; " ") | .[0:70])
          else "" end))
    ] | join("\t")'
}

cmd_text() {
  local id="${1:?id required}"
  makoctl history -j | jq -r --argjson id "$id" '
    .[] | select(.id == $id)
    | [(.summary // ""), (.body // "")] | map(select(. != "")) | join("\n")'
}

silent_on()  { makoctl mode -a silent >/dev/null; }
silent_off() { makoctl mode -r silent >/dev/null 2>&1 || true; }

# Достаёт уведомление <id> из истории на экран (невидимо, под mode=silent):
# restore снимает записи с верхушки истории, пока не снимет целевую. Снятые ДО
# целевой складывает в RESTORED_ABOVE (от новых к старым). 1 — если id не нашёлся.
RESTORED_ABOVE=()
pluck() {
  local target="$1" id
  silent_on
  while read -r id; do
    makoctl restore
    [[ "$id" == "$target" ]] && return 0
    RESTORED_ABOVE+=("$id")
  done < <(makoctl history -j | jq -r '.[].id')
  return 1
}

# Возвращает снятые pluck-ом записи обратно в историю. dismiss кладёт в историю
# сверху, поэтому идём от старых к новым — исходный порядок сохраняется.
restack() {
  local i
  for ((i = ${#RESTORED_ABOVE[@]} - 1; i >= 0; i--)); do
    makoctl dismiss -n "${RESTORED_ABOVE[$i]}"
  done
}

cmd_delete() {
  local id="${1:?id required}"
  trap silent_off EXIT
  if ! pluck "$id"; then
    restack
    notify_error "Уведомление $id не найдено в истории (・_・;)"
    exit 1
  fi
  makoctl dismiss -n "$id" -h
  restack
  silent_off
  signal_waybar
}

cmd_restore() {
  local id="${1:?id required}"
  trap silent_off EXIT
  if ! pluck "$id"; then
    restack
    notify_error "Уведомление $id не найдено в истории (・_・;)"
    exit 1
  fi
  restack
  # После снятия silent целевое уведомление отрисовывается (если не активен DND).
  silent_off
  signal_waybar
}

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
  status)  cmd_status ;;
  dnd)     shift; cmd_dnd "$@" ;;
  clear)   cmd_clear ;;
  delete)  shift; cmd_delete "$@" ;;
  restore) shift; cmd_restore "$@" ;;
  menu)    cmd_menu ;;
  text)    shift; cmd_text "$@" ;;
  *) notify_error "Usage: notify-center.sh status|dnd|clear|delete|restore|menu|text ..."; exit 1 ;;
esac
