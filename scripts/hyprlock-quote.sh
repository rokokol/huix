#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
hyprlock-quote.sh — диалог Моники для DDLC-локскрина

Скрипт рендерит диалоговый бокс (фон + имя + реплика) целиком в PNG
ImageMagick'ом; hyprlock показывает его image-виджетом с reload_time=1.

Режимы:
  frame   тик машины состояний (дёргается reload_cmd раз в секунду):
          реплики из assets/monika-talk.txt топик за топиком, длительность
          реплики = время чтения + Exp(1/7), пустой бокс Exp(1/60) между
          топиками. Первый топик при каждом локе — из monika-reentry.txt
          (Act 3 re-entry), в случайную ротацию эти реплики не попадают.
          Печатает путь к текущему PNG; сам рендер уходит в фон, чтобы
          не блокировать hyprlock (reload_cmd синхронный)
  lock    обёртка для hypridle lock_cmd: подготовить первый кадр и exec
          hyprlock
  render  <имя> <текст> — внутренний фоновой рендер кадра
  help    эта справка

Глитчи — единый механизм для неправильного пароля (pam-ошибка hyprlock в
журнале) и спонтанных срабатываний (пуассоновский поток): экран глитчится
через `screen-shader.sh flash glitch` (композиция поверх активного эффекта),
одновременно имя и текст коверкаются «сломанной кодировкой»; текст глитчит
дольше шейдера и перерисовывается каждый тик — мусор «живёт».

Шрифт берётся из системы (fc-match Doki — с fallback'ом, если Doki нет).
Состояние — $XDG_RUNTIME_DIR/hypr-ddlc; кадр и кэш подложки —
~/.cache/huix (путь к кадру стабилен: его знает hyprlock.nix). Новый лок
распознаётся по смене PID hyprlock и начинает диалог с реплики перезахода.
EOF
}

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
export HUIX

QUOTES="$HUIX/assets/monika-talk.txt"
REENTRY="$HUIX/assets/monika-reentry.txt"
BOX_ASSET="$HUIX/assets/ddlc-stickers/dialog_box.png"

CPS=30 # скорость чтения, символов в секунду (доля показа реплики)

LINE_MEAN=7 # пауза после прочтения реплики: Exp(1/7), сек
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

# Геометрия кадра: подложка = бокс из ассета, -trim + 200% -> 1632x370.
# Плашка имени и текстовая область — координаты на этом холсте.
NAME_PT=52
NAME_BOX=336x76
NAME_XY=+68+0
NAME_OUTLINE='#e2679b' # розовая обводка имени
TEXT_PT=46
TEXT_W=1432
TEXT_XY=+100+106
TEXT_OUTLINE='#000000ff' # обводка реплик
TEXT_STROKE=1            # её толщина, px холста

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/huix"
OUT="$CACHE_DIR/hyprlock-dialog.png" # путь стабильный — прошит в hyprlock.nix
BASE="$CACHE_DIR/hyprlock-dialog-base.png"

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc"
STATE="$STATE_DIR/state"       # sourceable-переменные машины состояний
TOPIC="$STATE_DIR/topic.txt"   # несказанные реплики текущего топика
CUR="$STATE_DIR/cur.txt"       # текущая реплика
RENDERED="$STATE_DIR/rendered" # ключ (cksum) последнего отрендеренного кадра

# Дефолты состояния (первый запуск = сразу реплика перезахода).
phase=reentry
until_ms=0
next_glitch_ms=0
glitch_until_ms=0
fail_ts=""
last_pid=""

load_state() {
  # shellcheck disable=SC1090
  [[ -f "$STATE" ]] && source "$STATE" || true
}

save_state() {
  printf 'phase=%s\nuntil_ms=%s\nnext_glitch_ms=%s\nglitch_until_ms=%s\nfail_ts=%q\nlast_pid=%q\n' \
    "$phase" "$until_ms" "$next_glitch_ms" "$glitch_until_ms" \
    "$fail_ts" "$last_pid" >"$STATE.tmp"
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

# Случайный топик из файла $1 -> $TOPIC. Блоки разделены пустой строкой,
# строки с '#' — комментарии.
new_topic() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN { RS = ""; srand(seed) }
    { gsub(/(^|\n)#[^\n]*/, ""); sub(/^\n+/, ""); if ($0 != "") b[++n] = $0 }
    END { if (n) print b[int(rand() * n) + 1] }
  ' "$1" >"$TOPIC"
}

# Снять первую реплику топика в $CUR; 1 — топик пуст.
next_line() {
  local line
  line=$(head -n 1 "$TOPIC" 2>/dev/null || true)
  [[ -n "$line" ]] || return 1
  sed -i '1d' "$TOPIC"
  printf '%s' "${line//\[player\]/$USER}" >"$CUR"
}

# Показать текущую реплику: висит время чтения (len/CPS) + Exp(1/7).
show_line() {
  phase=shown
  until_ms=$((now_ms + $(wc -m <"$CUR") * 1000 / CPS + $(exp_ms "$LINE_MEAN" "$LINE_MIN" "$LINE_MAX")))
}

start_topic() {
  new_topic "$1"
  next_line
  show_line
}

# «Сломанная кодировка»: ~30% символов подменяются mojibake-глифами.
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

frame_key() {
  printf '%s\x1f%s' "$1" "$2" | cksum
}

# Подложка кадра: бокс из ассета без прозрачных полей, 2x для чёткости.
ensure_base() {
  [[ -f "$BASE" && "$BASE" -nt "$BOX_ASSET" ]] && return 0
  mkdir -p "$CACHE_DIR"
  magick "$BOX_ASSET" -trim +repage -resize 200% "$BASE.tmp.png"
  mv "$BASE.tmp.png" "$BASE"
}

# Рендер кадра: подложка + имя (белое с розовой обводкой через morphology
# dilate альфы) + реплика (двухпроходный caption: обводка цветом игры,
# затем белая заливка — раскладка проходов идентична, stroke не меняет
# метрики).
# Однокадровый фоновой процесс: очередной тик frame его перезапустит, если
# желаемый кадр успел смениться. label:/caption:@файл — чтобы % и \ в
# тексте не интерпретировались ImageMagick'ом.
cmd_render() {
  local name="$1" text="$2"
  mkdir -p "$STATE_DIR" "$CACHE_DIR"
  exec 9>"$STATE_DIR/.render.lock"
  flock -n 9 || exit 0

  ensure_base
  local font
  font=$(fc-match -f '%{file}' Doki)
  tmpd=$(mktemp -d "$STATE_DIR/render.XXXXXX")
  trap 'rm -rf "${tmpd:-}"' EXIT
  printf '%s' "$name" >"$tmpd/name"

  local args=(
    "$BASE"
    \( -background none -font "$font" -pointsize "$NAME_PT"
    -fill white label:@"$tmpd/name"
    \( +clone -channel A -morphology dilate disk:3.5 +channel
    -fill "$NAME_OUTLINE" -channel RGB -colorize 100 +channel \)
    +swap -composite -bordercolor none -border 8
    -gravity center -extent "$NAME_BOX" \)
    -gravity northwest -geometry "$NAME_XY" -composite
  )
  if [[ -n "$text" ]]; then
    printf '%s' "$text" >"$tmpd/text"
    local pass
    for pass in "-fill $TEXT_OUTLINE -stroke $TEXT_OUTLINE -strokewidth $TEXT_STROKE" "-fill white"; do
      # shellcheck disable=SC2206
      args+=(
        \( -background none -font "$font" -pointsize "$TEXT_PT"
        -interline-spacing 4 -size "${TEXT_W}x" $pass caption:@"$tmpd/text" \)
        -geometry "$TEXT_XY" -composite
      )
    done
  fi
  args+=("$tmpd/out.png")

  magick "${args[@]}"
  mv "$tmpd/out.png" "$OUT"
  frame_key "$name" "$text" >"$RENDERED"
}

cmd_frame() {
  [[ -d "$STATE_DIR" ]] || mkdir -p "$STATE_DIR"
  load_state
  now_ms=$(now_ms)

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

  # Спонтанные глитчи: пуассоновский поток.
  ((next_glitch_ms > 0)) || next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
  if ((now_ms >= next_glitch_ms)); then
    next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
    fire_glitch
  fi

  # Машина состояний: reentry -> shown -> ... -> gap -> shown -> ...
  case "$phase" in
    reentry) start_topic "$REENTRY" ;;
    shown)
      if ((now_ms >= until_ms)); then
        if next_line; then
          show_line
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

  # Желаемый кадр; во время глитча имя и текст коверкаются заново каждый
  # тик — ключ кадра меняется сам собой, рендер перезапускается.
  local name="Monika" text=""
  [[ "$phase" == "gap" ]] || text=$(<"$CUR")
  if ((now_ms < glitch_until_ms)); then
    name=$(glitch_text <<<"$name")
    [[ -n "$text" ]] && text=$(glitch_text <<<"$text")
  fi

  # Рендер в фоне: reload_cmd синхронный, блокировать hyprlock на время
  # magick нельзя. hyprlock подхватит кадр по mtime на следующем тике.
  if [[ "$(frame_key "$name" "$text")" != "$(cat "$RENDERED" 2>/dev/null)" ]]; then
    nohup "$0" render "$name" "$text" </dev/null >/dev/null 2>&1 &
    disown
  fi

  save_state
  printf '%s' "$OUT"
}

# Обёртка hypridle lock_cmd: первый кадр (пустой бокс вместо реплики
# прошлого лока) готовится в фоне и успевает до первой отрисовки.
cmd_lock() {
  mkdir -p "$STATE_DIR"
  rm -f "$RENDERED"
  nohup "$0" render "Monika" "" </dev/null >/dev/null 2>&1 &
  disown
  exec hyprlock
}

case "${1:-frame}" in
frame) cmd_frame ;;
lock) cmd_lock ;;
render) cmd_render "${2:-Monika}" "${3:-}" ;;
help | -h | --help) usage ;;
*)
  usage >&2
  exit 1
  ;;
esac
