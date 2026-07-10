#!/usr/bin/env bash

set -euo pipefail

# Диалог Моники для DDLC-локскрина: label в hyprlock поллит скрипт через
# cmd[update:150], скрипт отдаёт pango-разметку текущего кадра диалога.
#
# Машина состояний (state в $XDG_RUNTIME_DIR, переживает разлочку):
#   typing  -> реплика печатается побуквенно (CPS символов/сек);
#   shown   -> реплика дочитана, пауза ~ Exp(1/LINE_MEAN) до следующей;
#   fadeout -> текст плавно исчезает (FADE_MS мс), после чего -> typing/gap;
#   gap     -> топик кончился: пустой бокс ~ Exp(1/TOPIC_MEAN), потом новый
#              случайный топик из assets/monika-talk.txt (реплики идут
#              по порядку, как в игре).
#
# Первый диалог: при свежем локе всегда проигрывается случайный блок из
# monika-reentry.txt (Act 3 re-entry, "Quitting the Game"). Эти реплики
# НЕ попадают в обычную случайную ротацию.
#
# Глитчи: спонтанные — пуассоновский поток (интервалы ~ Exp(1/GLITCH_MEAN)),
# плюс на каждый неправильный пароль (pam-ошибка hyprlock в журнале, проверка
# раз в секунду). Глитч = текст коверкается мусорной «сломанной кодировкой»
# (случайные байты Latin-1/Cyrillic/CJK) на GLITCH_SEC.
#
# Верстка: у лейбла нет ни ширины, ни привязки к углу — поэтому в каждый кадр
# подмешивается невидимая (alpha=1/65536) «линейка» фиксированной ширины
# последней строкой, а непоказанный хвост реплики рендерится невидимым спаном.
# Размер текстуры получается постоянным: halign center даёт фиксированный
# левый край, valign bottom — фиксированный верх, буквы появляются на месте.

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
export HUIX

QUOTES="$HUIX/assets/monika-talk.txt"
REENTRY="$HUIX/assets/monika-reentry.txt"

CPS=30  # скорость печати, символов в секунду
WRAP=64 # перенос строк, символов (~строка текстовой области бокса)

LINE_MEAN=7 # пауза между репликами: Exp(1/7), сек
LINE_MIN=2
LINE_MAX=40

TOPIC_MEAN=60 # пустой бокс между топиками: Exp(1/60), сек
TOPIC_MIN=10
TOPIC_MAX=300

GLITCH_MEAN=120 # спонтанные глитчи: интервалы Exp(1/120), сек
GLITCH_MIN=15
GLITCH_MAX=600
GLITCH_SHADER_SEC=1.2 # длительность визуального глитча шейдера
GLITCH_TEXT_SEC=3.6   # длительность глитча текста

FADE_MS=600 # длительность плавного исчезновения текста, мс

# Невидимая линейка: точка + letter_spacing в pango-юнитах (1/1024 pt,
# px = юниты/768) даёт ~1180px — расширенную ширину текстовой области бокса.
RULER='<span alpha="1" letter_spacing="906240">.</span>'

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc"
STATE="$STATE_DIR/state"     # sourceable-переменные машины состояний
TOPIC="$STATE_DIR/topic.txt" # несказанные реплики текущего топика
CUR="$STATE_DIR/cur.txt"     # текущая реплика, уже с переносами

mkdir -p "$STATE_DIR"

now_ms=$(date +%s%3N)

# Дефолты (первый запуск): reentry-фаза — сразу проиграть приветствие.
phase=reentry
until_ms=0
reveal_ms=0
fade_start_ms=0
next_glitch_ms=0
glitch_until_ms=0
fail_chk=0
fail_ts=""
# shellcheck disable=SC1090
[[ -f "$STATE" ]] && source "$STATE"

save_state() {
  printf 'phase=%s\nuntil_ms=%s\nreveal_ms=%s\nfade_start_ms=%s\nnext_glitch_ms=%s\nglitch_until_ms=%s\nfail_chk=%s\nfail_ts=%q\n' \
    "$phase" "$until_ms" "$reveal_ms" "$fade_start_ms" "$next_glitch_ms" "$glitch_until_ms" "$fail_chk" "$fail_ts" >"$STATE.tmp"
  mv "$STATE.tmp" "$STATE"
}

# Экспоненциальная случайная пауза в мс: $1 = mean, $2 = min, $3 = max (сек).
exp_ms() {
  awk -v m="$1" -v lo="$2" -v hi="$3" -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      d = -m * log(1 - rand())
      if (d < lo) d = lo
      if (d > hi) d = hi
      printf "%d", d * 1000
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

# Случайный топик из monika-reentry.txt (re-entry приветствия).
new_reentry_topic() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN { RS = ""; srand(seed) }
    { gsub(/(^|\n)#[^\n]*/, ""); sub(/^\n+/, ""); if ($0 != "") b[++n] = $0 }
    END { if (n) print b[int(rand() * n) + 1] }
  ' "$REENTRY" >"$TOPIC"
}

# Снять первую реплику топика в $CUR (с переносами); 1 — топик пуст.
next_line() {
  local line
  line=$(head -n 1 "$TOPIC" 2>/dev/null || true)
  [[ -n "$line" ]] || return 1
  sed -i '1d' "$TOPIC"
  printf '%s' "${line//\[player\]/$USER}" | fold -s -w "$WRAP" | sed 's/ *$//' >"$CUR"
}

# Глитч-трансформация: «сломанная кодировка» — случайные глифы, имитирующие
# артефакты битой charset-конверсии (mojibake); ~30% символов подменяются.
# Перегенерируется каждый тик — мусор «живёт».
glitch_text() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      # Набор «мусорных» символов, имитирующих сломанную кодировку:
      # блочные элементы, кириллица, Latin-1, математические, спецсимволы.
      n = split("█ ▓ ▒ ░ ö ä ü é § ¿ Ж Щ Ф Ю ъ « » † ‡ ß ƒ ¤ ∆ Ω ¶ × ¬ ‰ £ ¥", G, " ")
    }
    {
      out = ""
      for (i = 1; i <= length($0); i++) {
        c = substr($0, i, 1)
        out = out ((c != " " && rand() < 0.3) ? G[int(rand() * n) + 1] : c)
      }
      print out
    }'
}

esc() {
  local s="$1"
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  printf '%s' "$s"
}

# --- Неправильный пароль -> глитч (журнал поллим раз в секунду) ---
start_glitch=""
if ((now_ms / 1000 > fail_chk)); then
  fail_chk=$((now_ms / 1000))
  last=$(journalctl -q -t hyprlock -S -5s -g 'authentication failure' \
    -o short-unix 2>/dev/null | tail -n 1 | cut -d' ' -f1) || true
  if [[ -n "$last" && "$last" != "$fail_ts" ]]; then
    fail_ts="$last"
    start_glitch=1
  fi
fi

# --- Спонтанные глитчи: пуассоновский поток ---
((next_glitch_ms > 0)) || next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
if ((now_ms >= next_glitch_ms)); then
  start_glitch=1
  next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
fi

if [[ -n "$start_glitch" ]]; then
  glitch_until_ms=$((now_ms + $(awk -v s="$GLITCH_SEC" 'BEGIN { printf "%d", s * 1000 }')))
  # flash спит внутри — в фон и без наследования fd, иначе hyprlock ждёт EOF
  ("$HUIX/scripts/screen-shader.sh" flash glitch "$GLITCH_SEC" >/dev/null 2>&1 &)
fi

# --- Машина состояний диалога ---

# Первый запуск (reentry): проиграть приветствие из monika-reentry.txt.
if [[ "$phase" == "reentry" ]]; then
  new_reentry_topic
  next_line
  phase=typing
  reveal_ms=$now_ms
fi

# Fadeout завершён -> переход к следующей реплике или gap.
if [[ "$phase" == "fadeout" ]] && ((now_ms >= until_ms)); then
  if next_line; then
    phase=typing
    reveal_ms=$now_ms
  else
    phase=gap
    until_ms=$((now_ms + $(exp_ms "$TOPIC_MEAN" "$TOPIC_MIN" "$TOPIC_MAX")))
  fi
fi

# Shown -> начать fadeout вместо мгновенного перехода.
if [[ "$phase" == "shown" ]] && ((now_ms >= until_ms)); then
  phase=fadeout
  fade_start_ms=$now_ms
  until_ms=$((now_ms + FADE_MS))
fi

if [[ "$phase" == "gap" ]] && ((now_ms >= until_ms)); then
  new_topic
  next_line
  phase=typing
  reveal_ms=$now_ms
fi

# --- Кадр ---
shown=""
hidden=""
fade_alpha=65535  # полная непрозрачность (pango alpha 1..65535)
if [[ "$phase" != "gap" ]]; then
  full=$(<"$CUR")
  if [[ "$phase" == "typing" ]]; then
    n=$(((now_ms - reveal_ms) * CPS / 1000))
    if ((n >= ${#full})); then
      phase=shown
      until_ms=$((now_ms + $(exp_ms "$LINE_MEAN" "$LINE_MIN" "$LINE_MAX")))
      shown="$full"
    else
      shown="${full:0:n}"
      hidden="${full:n}"
    fi
  elif [[ "$phase" == "fadeout" ]]; then
    shown="$full"
    # Линейно уменьшаем альфу от 65535 до 0 за FADE_MS.
    elapsed=$((now_ms - fade_start_ms))
    if ((elapsed >= FADE_MS)); then
      fade_alpha=0
    else
      fade_alpha=$(( 65535 - 65535 * elapsed / FADE_MS ))
    fi
  else
    shown="$full"
  fi
fi

((now_ms < glitch_until_ms)) && [[ -n "$shown" ]] && shown=$(glitch_text <<<"$shown")

# Добиваем до 3 строк, чтобы высота текстуры не плясала (текст растёт вниз
# от фиксированного верха), последней строкой — линейка ширины.
lines=1
[[ "$phase" != "gap" ]] && lines=$(wc -l <<<"$full")
pad=""
for ((i = lines; i < 3; i++)); do pad+=$'\n'; done

# Оборачиваем видимый текст в span с альфой для fadeout.
if ((fade_alpha < 65535)); then
  printf '<span alpha="%d">%s</span><span alpha="1">%s</span>%s\n%s' \
    "$fade_alpha" "$(esc "$shown")" "$(esc "$hidden")" "$pad" "$RULER"
else
  printf '%s<span alpha="1">%s</span>%s\n%s' \
    "$(esc "$shown")" "$(esc "$hidden")" "$pad" "$RULER"
fi

save_state
