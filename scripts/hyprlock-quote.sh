#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
hyprlock-quote.sh — диалог Моники для DDLC-локскрина

Режимы (дёргаются label cmd[update:N] из hyprlock.nix):
  frame   кадр диалога pango-разметкой: побуквенная печать реплик из
          assets/monika-talk.txt топик за топиком, пауза Exp(1/7) после
          реплики, плавное затухание, пустой бокс Exp(1/60) между
          топиками. Первый топик при каждом локе — из monika-reentry.txt
          (Act 3 re-entry), в случайную ротацию эти реплики не попадают
  name    имя на плашке ("Monika")
  help    эта справка

Печать — приём Ren'Py: каждый кадр рендерится вся реплика целиком, а ещё
не «напечатанный» хвост прячется в прозрачный span. Размер текстуры от
этого постоянен всю жизнь реплики, и текст прибит к месту без всяких
измерений шрифта; перенос строк — просто fold по числу символов.

Глитчи — единый механизм для неправильного пароля (pam-ошибка hyprlock в
журнале) и спонтанных срабатываний (пуассоновский поток): экран глитчится
через `screen-shader.sh flash glitch` (композиция поверх активного эффекта),
одновременно имя и текст коверкаются «сломанной кодировкой»; текст глитчит
дольше шейдера.

Геометрию задаёт hyprlock.nix через окружение:
  TEXT_W   ширина текстовой области бокса, px (деф. 1114)
  FONT_PX  кегль реплики, px (font_size * 4/3; деф. 32) — от него
           считаются метрики переноса и пробельной строки-ширины

Состояние — $XDG_RUNTIME_DIR/hypr-ddlc; новый лок распознаётся по смене
PID hyprlock и начинает диалог с реплики перезахода.
EOF
}

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
export HUIX

QUOTES="$HUIX/assets/monika-talk.txt"
REENTRY="$HUIX/assets/monika-reentry.txt"

TEXT_W="${TEXT_W:-1114}"
FONT_PX="${FONT_PX:-32}"
# Метрики Doki относительно кегля: при 32px глиф в среднем 15px, пробел 8px.
AVG_ADV=$((FONT_PX * 15 / 32))
SPACE_ADV=$((FONT_PX / 4))
WRAP_CHARS=$((TEXT_W * 9 / (AVG_ADV * 10))) # перенос с запасом ~10%
BOX_LINES=3                                 # строк в текстовой области

CPS=10 # скорость печати, символов в секунду

LINE_MEAN=7 # пауза после реплики: Exp(1/7), сек
LINE_MIN=2
LINE_MAX=40

TOPIC_MEAN=60 # пустой бокс между топиками: Exp(1/60), сек
TOPIC_MIN=10
TOPIC_MAX=300

GLITCH_MEAN=120 # спонтанные глитчи: интервалы Exp(1/120), сек
GLITCH_MIN=15
GLITCH_MAX=600
GLITCH_SHADER_SEC=1.2 # длительность глитч-шейдера
GLITCH_TEXT_MS=3600   # текст глитчит дольше шейдера

FADE_MS=600 # плавное исчезновение реплики

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc"
STATE="$STATE_DIR/state"     # sourceable-переменные машины состояний
TOPIC="$STATE_DIR/topic.txt" # несказанные реплики текущего топика
CUR="$STATE_DIR/cur.txt"     # текущая реплика, уже с переносами

# Дефолты состояния (первый запуск = сразу реплика перезахода).
phase=reentry
until_ms=0
reveal_ms=0
next_glitch_ms=0
glitch_until_ms=0
fail_chk=0
fail_ts=""
last_pid=""

# Единый список полей машины состояний: save/snapshot не разъезжаются
# при добавлении поля.
STATE_VARS=(phase until_ms reveal_ms next_glitch_ms glitch_until_ms fail_chk fail_ts last_pid)

load_state() {
  # shellcheck disable=SC1090
  [[ ! -f "$STATE" ]] || source "$STATE"
}

save_state() {
  local v
  for v in "${STATE_VARS[@]}"; do printf '%s=%q\n' "$v" "${!v}"; done >"$STATE.tmp"
  mv "$STATE.tmp" "$STATE"
}

state_snapshot() {
  local v
  for v in "${STATE_VARS[@]}"; do printf '%s|' "${!v}"; done
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

# Случайный топик из файла $1 -> $TOPIC. Блоки разделены пустой строкой,
# строки с '#' — комментарии.
new_topic() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN { RS = ""; srand(seed) }
    { gsub(/(^|\n)#[^\n]*/, ""); sub(/^\n+/, ""); if ($0 != "") b[++n] = $0 }
    END { if (n) print b[int(rand() * n) + 1] }
  ' "$1" >"$TOPIC"
}

# Снять первую реплику топика в $CUR (с переносами); 1 — топик пуст.
next_line() {
  local line
  line=$(head -n 1 "$TOPIC" 2>/dev/null || true)
  [[ -n "$line" ]] || return 1
  sed -i '1d' "$TOPIC"
  printf '%s\n' "${line//\[player\]/$USER}" |
    fold -s -w "$WRAP_CHARS" | sed 's/ *$//' >"$CUR"
}

# «Сломанная кодировка»: ~30% символов подменяются mojibake-глифами;
# перегенерируется на каждый вызов — мусор «живёт».
glitch_text() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      n = split("Ã Ð Ñ Â Ø Þ ß ð þ ¤ ¥ § ¶ ¿ ¬ Œ ž Æ é ö ъ Ж �", G, " ")
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

# Глитч экрана и текста одним механизмом (пароль и пуассоновский поток).
# flash спит внутри — отвязываем полностью, иначе hyprlock ждёт EOF.
fire_glitch() {
  glitch_until_ms=$((now_ms + GLITCH_TEXT_MS))
  nohup "$HUIX/scripts/screen-shader.sh" flash glitch "$GLITCH_SHADER_SEC" \
    </dev/null >/dev/null 2>&1 &
  disown
}

# Миллисекунды без спавна date: EPOCHREALTIME = "sec.usec" (bash >= 5;
# разделитель зависит от локали — срезаем и точку, и запятую).
now_ms() {
  local t=${EPOCHREALTIME//[.,]/}
  printf '%s' "${t:0:-3}"
}

esc() {
  local s="$1"
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  printf '%s' "$s"
}

start_typing() {
  phase=typing
  reveal_ms=$now_ms
}

start_topic() {
  new_topic "$1"
  next_line
  start_typing
}

# Мojibake-глифы рендерятся fallback-шрифтом с другими метриками строки —
# без якорей глитч менял бы высоту текстуры и имя прыгало бы. Невидимые
# крайние глифы держат метрики (и, симметрично, центровку) постоянными.
cmd_name() {
  load_state
  local name="Monika" anchor='<span alpha="1">�Жð</span>'
  (($(now_ms) < glitch_until_ms)) && name=$(glitch_text <<<"$name")
  printf '%s%s%s' "$anchor" "$name" "$anchor"
}

cmd_frame() {
  [[ -d "$STATE_DIR" ]] || mkdir -p "$STATE_DIR"
  load_state
  local state_in
  state_in=$(state_snapshot)
  now_ms=$(now_ms)

  # Тяжёлые проверки (скан /proc, журнал) — не чаще раза в секунду.
  if ((now_ms / 1000 > fail_chk)); then
    fail_chk=$((now_ms / 1000))

    # Новый лок (смена PID hyprlock) -> диалог с реплики перезахода.
    local pid
    pid=$(pidof hyprlock 2>/dev/null) || pid=""
    pid=${pid%% *}
    if [[ -n "$pid" && "$pid" != "$last_pid" ]]; then
      last_pid="$pid"
      phase=reentry
    fi

    # Неправильный пароль (pam-ошибка hyprlock в журнале) -> глитч.
    local last
    last=$(journalctl -q -t hyprlock -S -5s -g 'authentication failure' \
      -o short-unix 2>/dev/null | tail -n 1 | cut -d' ' -f1) || true
    if [[ -n "$last" && "$last" != "$fail_ts" ]]; then
      fail_ts="$last"
      fire_glitch
    fi
  fi

  # Спонтанные глитчи: пуассоновский поток. 0 — ещё не запланирован,
  # тогда только назначаем первый интервал, без срабатывания.
  if ((now_ms >= next_glitch_ms)); then
    ((next_glitch_ms > 0)) && fire_glitch
    next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
  fi

  # Машина состояний: reentry -> typing -> shown -> fadeout -> typing|gap.
  case "$phase" in
  reentry)
    start_topic "$REENTRY"
    ;;
  shown)
    if ((now_ms >= until_ms)); then
      phase=fadeout
      reveal_ms=$now_ms # старт затухания
      until_ms=$((now_ms + FADE_MS))
    fi
    ;;
  fadeout)
    if ((now_ms >= until_ms)); then
      if next_line; then
        start_typing
      else
        phase=gap
        until_ms=$((now_ms + $(exp_ms "$TOPIC_MEAN" "$TOPIC_MIN" "$TOPIC_MAX")))
      fi
    fi
    ;;
  gap)
    if ((now_ms >= until_ms)); then
      start_topic "$QUOTES"
    fi
    ;;
  esac

  # Кадр: вся реплика целиком, ненапечатанный хвост — прозрачным span'ом
  # (приём Ren'Py). Размер текстуры постоянен всю жизнь реплики.
  local full="" n=0 fade_alpha=65535
  if [[ "$phase" != "gap" ]]; then
    full=$(<"$CUR")
    case "$phase" in
    typing)
      n=$(((now_ms - reveal_ms) * CPS / 1000))
      if ((n >= ${#full})); then
        phase=shown
        until_ms=$((now_ms + $(exp_ms "$LINE_MEAN" "$LINE_MIN" "$LINE_MAX")))
        n=${#full}
      fi
      ;;
    fadeout)
      n=${#full}
      fade_alpha=$((65535 - 65535 * (now_ms - reveal_ms) / FADE_MS))
      ((fade_alpha >= 1)) || fade_alpha=1
      ;;
    *)
      n=${#full}
      ;;
    esac
    ((now_ms < glitch_until_ms)) && full=$(glitch_text <<<"$full")
  fi

  local body
  body=$(esc "${full:0:n}")
  ((n < ${#full})) && body+="<span alpha=\"1\">$(esc "${full:n}")</span>"
  ((fade_alpha < 65535)) && body="<span alpha=\"$fade_alpha\">$body</span>"

  # Кадр всегда BOX_LINES строк + строка-ширина из пробелов: добивка
  # пустыми строками держит высоту текстуры постоянной, пробельная строка
  # — её ширину (у label нет ни width, ни привязки к углу, но при
  # постоянном размере текстуры halign center + valign bottom дают
  # фиксированный левый верх). Требует text_trim=false в hyprlock.
  local nl pad=""
  nl=${full//[!$'\n']/}
  for ((i = ${#nl} + 1; i < BOX_LINES; i++)); do pad+=$'\n'; done
  printf '%s%s\n%*s' "$body" "$pad" $((TEXT_W / SPACE_ADV)) ''

  # Во время печати кадр — функция от reveal_ms: состояние не меняется,
  # и на частом опросе писать его каждый тик незачем.
  [[ -f "$STATE" && "$state_in" == "$(state_snapshot)" ]] || save_state
}

case "${1:-frame}" in
frame) cmd_frame ;;
name) cmd_name ;;
help | -h | --help) usage ;;
*)
  usage >&2
  exit 1
  ;;
esac
