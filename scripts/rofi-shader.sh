#!/usr/bin/env bash

# Выбор полноэкранного шейдера через rofi. По выбору вызывает screen-shader.sh.

set -euo pipefail

require_env() {
  if [[ -z "${HUIX:-}" ]]; then
    command -v notify-send >/dev/null 2>&1 &&
      notify-send -u critical "Shader error (╯°□°）╯︵ ┻━┻" "HUIX is not set"
    exit 1
  fi
}

require_env

# Список «подпись|значение» берём из screen-shader.sh — единый источник эмодзи
# и подписей (не дублируем здесь).
mapfile -t ENTRIES < <("$HUIX/scripts/screen-shader.sh" menu)

labels=$(printf '%s\n' "${ENTRIES[@]}" | cut -d'|' -f1)

choice=$(printf '%s\n' "$labels" | rofi -dmenu -i -p "📺" -mesg "Эффект на весь экран")
[[ -z "$choice" ]] && exit 0

for e in "${ENTRIES[@]}"; do
  if [[ "${e%%|*}" == "$choice" ]]; then
    exec "$HUIX/scripts/screen-shader.sh" effect set "${e##*|}"
  fi
done
