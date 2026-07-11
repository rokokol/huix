#!/usr/bin/env bash

set -euo pipefail

require_env() {
  if [[ -z "${HUIX:-}" ]]; then
    command -v notify-send >/dev/null 2>&1 &&
      notify-send -u critical "Shader error (╯°□°）╯︵ ┻━┻" "HUIX is not set"
    exit 1
  fi
}

require_env

# Вне rofi — лаунчер: запускаем rofi с этим же скриптом в роли modi "shader".
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show shader -modi "shader:$0" -mesg "Эффект на весь экран"
fi

SS="$HUIX/scripts/screen-shader.sh"

# Служебные значения кнопок яркости (не эффекты) — обрабатываются отдельно.
BRIGHT_UP="__bright_up__"
BRIGHT_DOWN="__bright_down__"

# Выбран пункт — его значение rofi кладёт в ROFI_INFO. Кнопки яркости дёргают
# софт-яркость менеджера; всё остальное — ТУМБЛЕР эффекта (toggle): нет в стопке —
# добавить, есть — убрать. Эффекты компонуются, пока их не убрать по одному или не
# сбросить всё («Обычный» = clear). НЕ выходим (не exec) — печатаем список заново,
# чтобы rofi остался открыт и можно было тыкать подряд; номера применения (01. 02. …)
# у активных и уровень яркости обновятся. Escape закроет.
if [[ -n "${ROFI_INFO:-}" ]]; then
  case "$ROFI_INFO" in
  "$BRIGHT_UP") "$SS" bright up ;;
  "$BRIGHT_DOWN") "$SS" bright down ;;
  *) "$SS" effect toggle "$ROFI_INFO" ;;
  esac
fi

# keep-selection: после применения пункта rofi перерисовывает список — без этого
# курсор прыгал бы в начало. С опцией позиция сохраняется, так что можно тыкать
# эффекты/яркость подряд, не листая заново (rofi >= 1.7; тут 2.0).
printf '\0keep-selection\x1ftrue\n'
# Текущий уровень софт-яркости — в message над списком, обновляется на каждый тык.
printf '\0message\x1fЭффект на весь экран · яркость %s%%\n' "$("$SS" bright get)"

# Печатаем эффекты: видимая подпись + скрытое значение (info). Активные помечены
# номером применения (01. 02. …) — см. cmd_menu в screen-shader.sh. Сразу после
# «Обычный» (сброс) вставляем кнопки регулировки софт-яркости — разные эмодзи
# (☀️ ярче / 🌑 темнее) для наглядности; вместе с keep-selection удобно жать подряд.
while IFS='|' read -r label value; do
  printf '%s\0info\x1f%s\n' "$label" "$value"
  if [[ "$value" == "none" ]]; then
    printf '🌕 Яркость +\0info\x1f%s\n' "$BRIGHT_UP"
    printf '🌑 Яркость −\0info\x1f%s\n' "$BRIGHT_DOWN"
  fi
done < <("$SS" menu)
