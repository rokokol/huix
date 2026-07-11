#!/usr/bin/env bash

# Лента уведомлений mako в rofi (script-modi, как rofi-shader.sh): тумблер DND,
# очистка истории, клик по уведомлению копирует его текст. Вся логика — в
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

# Ширина строки списка в символах: rofi не умеет перенос внутри элемента
# (однострочный, обрезается на …), поэтому длинный текст заворачиваем сами —
# как в rofi-wooordhunt.sh.
WRAP_WIDTH=60

# Вне rofi — лаунчер: запускаем rofi с этим же скриптом в роли modi.
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show notifications -modi "notifications:$0" -mesg "Центр уведомлений"
fi

# Главный список. У строк уведомлений в info лежит id, у служебных — команда.
print_top() {
  local menu id icon label
  menu=$("$NC" menu)
  [[ -n "$menu" ]] && printf '🧹 Очистить историю (ﾉ>ω<)ﾉ ･ﾟ✧\0info\x1fcmd:clear\n'
  if [[ "$("$NC" dnd status)" == "on" ]]; then
    printf '🔔 Включить уведомления ヽ(・∀・)ﾉ\0info\x1fcmd:dnd\n'
  else
    printf '🔕 Не беспокоить (－ω－) zzZ\0info\x1fcmd:dnd\n'
  fi
  [[ -n "$menu" ]] || return 0
  # Разделитель \x1f, не TAB: whitespace-IFS схлопывает пустое поле иконки,
  # и label уезжает в icon (см. cmd_menu в notify-center.sh).
  local first line
  while IFS=$'\x1f' read -r id icon label; do
    # Первая строка — сам элемент, хвост — невыбираемые строки-продолжения
    # с тем же id: случайный Enter по ним всё равно скопирует текст.
    first=1
    while IFS= read -r line; do
      if ((first)); then
        first=0
        if [[ -n "$icon" ]]; then
          printf '%s\0info\x1fid:%s\x1ficon\x1f%s\n' "$line" "$id" "$icon"
        else
          printf '%s\0info\x1fid:%s\n' "$line" "$id"
        fi
      else
        printf '   %s\0info\x1fid:%s\x1fnonselectable\x1ftrue\n' "$line" "$id"
      fi
    done < <(fold -s -w "$WRAP_WIDTH" <<<"$label")
  done <<<"$menu"
}

# Пустой вывод закрывает rofi; печать нового списка — продолжает сессию.
case "${ROFI_INFO:-}" in
  "")        print_top ;;
  cmd:dnd)   "$NC" dnd toggle ;;
  cmd:clear) "$NC" clear ;;
  id:*)      "$NC" text "${ROFI_INFO#id:}" | wl-copy ;;
esac
