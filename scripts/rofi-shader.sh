#!/usr/bin/env bash

# Пикер полноэкранного шейдера как rofi script-modi (modi "shader").
# Вне rofi (ROFI_RETV не задан) — лаунчер: открываем rofi с этим же скриптом в
# роли modi, чтобы и хоткей, и клик в waybar звали один скрипт без дублирования
# команды rofi. Промпт пикера (📺) задаётся в конфиге rofi через display-shader
# (как display-dictionary и т.п.), а не флагом -p. Пункты и эмодзи берём из
# screen-shader.sh menu — единый источник.

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

# Выбран пункт — его значение rofi кладёт в ROFI_INFO. Применяем эффект.
if [[ -n "${ROFI_INFO:-}" ]]; then
  exec "$HUIX/scripts/screen-shader.sh" effect set "$ROFI_INFO"
fi

# Первый вызов от rofi — печатаем пункты: видимая подпись + скрытое значение (info).
while IFS='|' read -r label value; do
  printf '%s\0info\x1f%s\n' "$label" "$value"
done < <("$HUIX/scripts/screen-shader.sh" menu)
