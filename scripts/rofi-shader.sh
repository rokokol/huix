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

# Выбран пункт — его значение rofi кладёт в ROFI_INFO. Выбор работает как ТУМБЛЕР
# (toggle): нет в стопке — добавить, есть — убрать. Эффекты компонуются, пока их
# не убрать по одному или не сбросить всё («Обычный» = clear). НЕ выходим (не exec) —
# печатаем список заново, чтобы rofi остался открыт и можно было настакать/поснимать
# несколько эффектов подряд; номера применения (01. 02. …) у активных обновятся. Escape закроет.
if [[ -n "${ROFI_INFO:-}" ]]; then
  "$HUIX/scripts/screen-shader.sh" effect toggle "$ROFI_INFO"
fi

# Печатаем пункты: видимая подпись + скрытое значение (info). Активные помечены
# номером применения (01. 02. …)
# (см. cmd_menu в screen-shader.sh) — видно накопленную стопку.
while IFS='|' read -r label value; do
  printf '%s\0info\x1f%s\n' "$label" "$value"
done < <("$HUIX/scripts/screen-shader.sh" menu)
