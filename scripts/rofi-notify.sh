#!/usr/bin/env bash

# Лента уведомлений mako (видимые попапы + история) в rofi (script-modi, как
# rofi-shader.sh). Верхний уровень: тумблер DND, очистка истории и сами
# уведомления (новые сверху). Выбор уведомления открывает меню: действия самого
# уведомления (⚡) / скопировать текст / удалить. Вся логика — в
# notify-center.sh, здесь только представление.

set -euo pipefail

require_env() {
  if [[ -z "${HUIX:-}" ]]; then
    command -v notify-send >/dev/null 2>&1 &&
      notify-send -u critical "Notify center error (╯°□°）╯︵ ┻━┻" "HUIX is not set"
    exit 1
  fi
}

require_env

NC="$HUIX/scripts/notify-center.sh"

# Вне rofi — лаунчер: запускаем rofi с этим же скриптом в роли modi.
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show notifications -modi "notifications:$0" -mesg "Центр уведомлений"
fi

# Главный список. У строк уведомлений в info лежит id, у служебных — команда.
print_top() {
  if [[ "$("$NC" dnd status)" == "on" ]]; then
    printf '🔔 Включить уведомления ヽ(・∀・)ﾉ\0info\x1fcmd:dnd\n'
  else
    printf '🔕 Не беспокоить (－ω－) zzZ\0info\x1fcmd:dnd\n'
  fi
  local menu id icon label
  menu=$("$NC" menu)
  [[ -n "$menu" ]] || return 0
  printf '🧹 Очистить историю (ﾉ>ω<)ﾉ ･ﾟ✧\0info\x1fcmd:clear\n'
  while IFS=$'\t' read -r id icon label; do
    if [[ -n "$icon" ]]; then
      printf '%s\0info\x1fid:%s\x1ficon\x1f%s\n' "$label" "$id" "$icon"
    else
      printf '%s\0info\x1fid:%s\n' "$label" "$id"
    fi
  done <<<"$menu"
}

print_item_menu() {
  local id="$1" key label
  # Действия самого уведомления (если есть). В info ключ идёт ПОСЛЕ id:
  # id числовой, поэтому разбор по первому двоеточию однозначен,
  # даже если в ключе действия есть свои двоеточия.
  while IFS=$'\t' read -r key label; do
    [[ -n "$key" ]] || continue
    printf '⚡ %s (☆ω☆)\0info\x1fact:invoke:%s:%s\n' "$label" "$id" "$key"
  done < <("$NC" actions "$id")
  printf '📋 Скопировать текст φ(．．)\0info\x1fact:copy:%s\n' "$id"
  printf '🗑️ Удалить (ﾉ´･ω･)ﾉ ﾐ ┻━┻\0info\x1fact:delete:%s\n' "$id"
  printf '↩️ Назад (￣▽￣)ノ\0info\x1fcmd:top\n'
}

# Пустой вывод закрывает rofi; печать нового списка — продолжает сессию.
case "${ROFI_INFO:-}" in
  "" | cmd:top)  print_top ;;
  cmd:dnd)       "$NC" dnd toggle ;;
  cmd:clear)     "$NC" clear ;;
  id:*)          print_item_menu "${ROFI_INFO#id:}" ;;
  act:invoke:*)  rest="${ROFI_INFO#act:invoke:}"; "$NC" invoke "${rest%%:*}" "${rest#*:}" ;;
  act:copy:*)    "$NC" text "${ROFI_INFO#act:copy:}" | wl-copy ;;
  act:delete:*)  "$NC" delete "${ROFI_INFO#act:delete:}"; print_top ;;
esac
