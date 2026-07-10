#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
hyprlock-quote.sh — диалог Моники для DDLC-локскрина

Режимы (дёргаются label cmd[update:N] из hyprlock.nix):
  frame   кадр диалога pango-разметкой: побуквенная печать реплик из
          assets/monika-talk.txt топик за топиком, паузы Exp(1/7) между
          репликами, плавное затухание, пустой бокс Exp(1/60) между
          топиками. Первый топик при каждом локе — из monika-reentry.txt
          (Act 3 re-entry), в случайную ротацию эти реплики не попадают
  name    имя на плашке ("Monika")
  help    эта справка

Глитчи — единый механизм для неправильного пароля (pam-ошибка hyprlock в
журнале) и спонтанных срабатываний (пуассоновский поток): экран глитчится
через `screen-shader.sh flash glitch` (композиция поверх активного эффекта),
одновременно текст и имя коверкаются «сломанной кодировкой»; текст глитчит
дольше шейдера.

Геометрию текста задаёт hyprlock.nix через окружение:
  TEXT_W    ширина текстовой области бокса, px (деф. 1084)
  ADVANCES  таблица ширин глифов "<символ> <px>" для пиксельного переноса
            строк (собирается на этапе сборки; без неё — AVG_ADV на символ)

Состояние — $XDG_RUNTIME_DIR/hypr-ddlc; новый лок распознаётся по смене PID
hyprlock и начинает диалог с реплики перезахода.
EOF
}

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
export HUIX

QUOTES="$HUIX/assets/monika-talk.txt"
REENTRY="$HUIX/assets/monika-reentry.txt"

TEXT_W="${TEXT_W:-1084}"
ADVANCES="${ADVANCES:-}"
AVG_ADV=15 # ширина глифа по умолчанию, px (нет в таблице / таблицы нет)

CPS=30 # скорость печати, символов в секунду

LINE_MEAN=7 # пауза между репликами: Exp(1/7), сек
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

load_state() {
  # shellcheck disable=SC1090
  [[ -f "$STATE" ]] && source "$STATE" || true
}

save_state() {
  printf 'phase=%s\nuntil_ms=%s\nreveal_ms=%s\nnext_glitch_ms=%s\nglitch_until_ms=%s\nfail_chk=%s\nfail_ts=%q\nlast_pid=%q\n' \
    "$phase" "$until_ms" "$reveal_ms" "$next_glitch_ms" "$glitch_until_ms" \
    "$fail_chk" "$fail_ts" "$last_pid" >"$STATE.tmp"
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

# Пиксельный перенос строк по таблице ширин глифов — строки заполняют
# текстовую область целиком независимо от ширины конкретных символов.
wrap_px() {
  awk -v W="$TEXT_W" -v AVG="$AVG_ADV" -v tbl="$ADVANCES" '
    BEGIN {
      if (tbl != "")
        while ((getline l < tbl) > 0) adv[substr(l, 1, 1)] = substr(l, 3) + 0
      sp = (" " in adv) ? adv[" "] : AVG
    }
    function wpx(w,  i, s, ch) {
      s = 0
      for (i = 1; i <= length(w); i++) {
        ch = substr(w, i, 1)
        s += (ch in adv) ? adv[ch] : AVG
      }
      return s
    }
    {
      n = split($0, ws, " ")
      cur = ""; cw = 0
      for (i = 1; i <= n; i++) {
        w = wpx(ws[i])
        if (cur == "") { cur = ws[i]; cw = w }
        else if (cw + sp + w > W) { print cur; cur = ws[i]; cw = w }
        else { cur = cur " " ws[i]; cw += sp + w }
      }
      if (cur != "") print cur
    }'
}

# Снять первую реплику топика в $CUR (с переносами); 1 — топик пуст.
next_line() {
  local line
  line=$(head -n 1 "$TOPIC" 2>/dev/null || true)
  [[ -n "$line" ]] || return 1
  sed -i '1d' "$TOPIC"
  printf '%s\n' "${line//\[player\]/$USER}" | wrap_px >"$CUR"
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

esc() {
  local s="$1"
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  printf '%s' "$s"
}

# Невидимая (alpha=1/65536) линейка шириной TEXT_W последней строкой кадра:
# у label нет ни ширины, ни привязки к углу, а постоянный размер текстуры
# даёт фиксированный левый верх при halign center + valign bottom.
# letter_spacing в pango-юнитах: px * 768 (1/1024 pt, 96 dpi).
ruler() {
  local dot=$AVG_ADV line
  if [[ -n "$ADVANCES" && -r "$ADVANCES" ]]; then
    while IFS= read -r line; do
      [[ "$line" == ". "* ]] && { dot=${line#. }; break; }
    done <"$ADVANCES"
  fi
  printf '<span alpha="1" letter_spacing="%d">.</span>' $(((TEXT_W - dot) * 768))
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

cmd_name() {
  load_state
  if (($(now_ms) < glitch_until_ms)); then
    printf '%s' "$(glitch_text <<<"Monika")"
  else
    printf 'Monika'
  fi
}

cmd_frame() {
  [[ -d "$STATE_DIR" ]] || mkdir -p "$STATE_DIR"
  load_state
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

  # --- Спонтанные глитчи: пуассоновский поток ---
  ((next_glitch_ms > 0)) || next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
  if ((now_ms >= next_glitch_ms)); then
    next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
    fire_glitch
  fi

  # --- Машина состояний: reentry -> typing -> shown -> fadeout -> typing|gap ---
  if [[ "$phase" == "reentry" ]]; then
    new_topic "$REENTRY"
    next_line
    phase=typing
    reveal_ms=$now_ms
  fi

  if [[ "$phase" == "fadeout" ]] && ((now_ms >= until_ms)); then
    if next_line; then
      phase=typing
      reveal_ms=$now_ms
    else
      phase=gap
      until_ms=$((now_ms + $(exp_ms "$TOPIC_MEAN" "$TOPIC_MIN" "$TOPIC_MAX")))
    fi
  fi

  if [[ "$phase" == "shown" ]] && ((now_ms >= until_ms)); then
    phase=fadeout
    reveal_ms=$now_ms # старт затухания
    until_ms=$((now_ms + FADE_MS))
  fi

  if [[ "$phase" == "gap" ]] && ((now_ms >= until_ms)); then
    new_topic "$QUOTES"
    next_line
    phase=typing
    reveal_ms=$now_ms
  fi

  # --- Кадр ---
  local full="" shown="" fade_alpha=65535 n
  if [[ "$phase" != "gap" ]]; then
    full=$(<"$CUR")
    case "$phase" in
      typing)
        n=$(((now_ms - reveal_ms) * CPS / 1000))
        if ((n >= ${#full})); then
          phase=shown
          until_ms=$((now_ms + $(exp_ms "$LINE_MEAN" "$LINE_MIN" "$LINE_MAX")))
          shown="$full"
        else
          shown="${full:0:n}"
        fi
        ;;
      fadeout)
        shown="$full"
        fade_alpha=$((65535 - 65535 * (now_ms - reveal_ms) / FADE_MS))
        ((fade_alpha >= 1)) || fade_alpha=1
        ;;
      *)
        shown="$full"
        ;;
    esac
  fi

  ((now_ms < glitch_until_ms)) && [[ -n "$shown" ]] && shown=$(glitch_text <<<"$shown")

  # Постоянная высота: реплика (<=3 строк) добивается пустыми строками до 3,
  # четвёртой идёт линейка. Требует general:text_trim=false в hyprlock.
  local nl lines pad=""
  nl=${full//[!$'\n']/}
  lines=$((${#nl} + 1))
  for ((i = lines; i < 3; i++)); do pad+=$'\n'; done

  local body
  body=$(esc "$shown")
  ((fade_alpha < 65535)) && body="<span alpha=\"$fade_alpha\">$body</span>"
  printf '%s%s\n%s' "$body" "$pad" "$(ruler)"

  save_state
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
