#!/usr/bin/env bash

set -euo pipefail

# Диалоговое окно Моники для DDLC-локскрина (image-виджет hyprlock).
#
# hyprlock поллит reload_cmd раз в секунду и перечитывает картинку по mtime.
# Текст рендерится в PNG поверх base-шаблона (ImageMagick): лейблы hyprlock
# не умеют ни обводку текста, ни multiline с привязкой к углу бокса —
# а у картинки полный контроль над версткой, как в игре.
#
# Реплики — assets/monika-talk.txt: случайный топик проходится построчно
# (одна строка = один текстбокс в игре), пауза между репликами ~ Exp(1/60)
# с клампом MIN..MAX. Дочитали топик — берём следующий случайный.
#
# Неправильный пароль (pam-ошибка hyprlock в журнале) -> короткий глитч
# всего экрана через screen-shader.sh flash.
#
# Использование: hyprlock-quote.sh <dialog-base.png>
# (шаблон бокса с плашкой Monika собирает Nix в hyprlock.nix).

BASE="${1:?usage: hyprlock-quote.sh <dialog-base.png>}"

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
export HUIX

QUOTES="$HUIX/assets/monika-talk.txt"

MEAN=60 # пауза между репликами: Exp(1/60), секунды
MIN=8
MAX=300

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc"
TOPIC="$STATE_DIR/topic.txt" # недосказанные реплики текущего топика
NEXT="$STATE_DIR/next"       # unix-время следующей смены реплики
FAIL_TS="$STATE_DIR/fail.ts" # timestamp последней учтённой pam-ошибки
DIALOG="$STATE_DIR/dialog.png"

mkdir -p "$STATE_DIR"

# Экспоненциальная случайная пауза (λ = 1/MEAN).
exp_delay() {
  awk -v m="$MEAN" -v lo="$MIN" -v hi="$MAX" -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      d = -m * log(1 - rand())
      if (d < lo) d = lo
      if (d > hi) d = hi
      printf "%d", d
    }'
}

# Случайный топик из monika-talk.txt: блоки разделены пустой строкой,
# строки с '#' — комментарии.
new_topic() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN { RS = ""; srand(seed) }
    { gsub(/(^|\n)#[^\n]*/, ""); sub(/^\n+/, ""); if ($0 != "") b[++n] = $0 }
    END { if (n) print b[int(rand() * n) + 1] }
  ' "$QUOTES" >"$TOPIC"
}

# Рендер реплики поверх шаблона: два прохода caption (чёрная обводка, потом
# белая заливка), перенос строк по ширине делает ImageMagick. Geometry
# завязана на шаблон 1632x370 (2x игрового бокса), собираемый в hyprlock.nix —
# менять согласованно. ~0.2 c раз в ~MEAN секунд; hyprlock ждёт reload_cmd
# синхронно, но разовый стоп на кадр незаметен.
render() {
  local font
  font=$(fc-match -f '%{file}' Doki)
  magick "$BASE" \
    \( -background none -font "$font" -pointsize 46 -interline-spacing 4 \
       -size 1432x -fill white -stroke black -strokewidth 3 caption:"$1" \) \
    -gravity northwest -geometry +100+106 -composite \
    \( -background none -font "$font" -pointsize 46 -interline-spacing 4 \
       -size 1432x -fill white -stroke none caption:"$1" \) \
    -gravity northwest -geometry +100+106 -composite \
    "png32:$DIALOG.tmp"
  mv "$DIALOG.tmp" "$DIALOG" # атомарно: hyprlock перечитывает по mtime
}

# --- Неправильный пароль -> глитч экрана ---
last=$(journalctl -q -t hyprlock -S -5s -g 'authentication failure' \
  -o short-unix 2>/dev/null | tail -n 1 | cut -d' ' -f1) || true
if [[ -n "$last" && "$last" != "$(cat "$FAIL_TS" 2>/dev/null)" ]]; then
  printf '%s' "$last" >"$FAIL_TS"
  # flash спит внутри — в фон и без наследования stdout, иначе hyprlock
  # будет ждать EOF всё время глитча
  ("$HUIX/scripts/screen-shader.sh" flash glitch 1.2 >/dev/null 2>&1 &)
fi

# --- Смена реплики ---
now=$(date +%s)
if [[ ! -s "$DIALOG" ]] || ((now >= $(cat "$NEXT" 2>/dev/null || echo 0))); then
  [[ -s "$TOPIC" ]] || new_topic
  line=$(head -n 1 "$TOPIC")
  sed -i '1d' "$TOPIC"
  render "${line//\[player\]/$USER}"
  echo $((now + $(exp_delay))) >"$NEXT"
fi

printf '%s' "$DIALOG"
