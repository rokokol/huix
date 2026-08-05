#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
hyprlock-quote.sh — Monika's dialog for the DDLC lock screen

Modes (invoked by label cmd[update:N] from hyprlock.nix):
  frame   dialog frame in pango markup: letter-by-letter typing of lines from
          assets/monika-talk.txt topic by topic, an Exp(1/7) pause after a
          line, a smooth fade-out, an empty box Exp(1/60) between topics. The
          first topic on every lock comes from monika-reentry.txt (Act 3
          re-entry); those lines never enter the random rotation. A topic never
          repeats the previous one from the same file
  name    the name on the plate ("Monika")
  help    this help

Typing is a Ren'Py trick: every frame renders the whole line, and the tail not
yet "typed" is hidden in a transparent span. The texture size stays constant for
the whole life of the line, and the text is pinned in place without any font
measurements; line wrapping is just a fold by character count

Glitches are a single mechanism for a wrong password (hyprlock pam error in the
journal) and spontaneous firings (a Poisson stream): the screen glitches via
`screen-shader.sh flash glitch` (composited over the active effect), at the same
time the name and text are garbled with a "broken encoding"; the text glitches
longer than the shader

Geometry is set by hyprlock.nix through the environment:
  TEXT_W   width of the box text area, px (default 1114)
  FONT_PX  line font size, px (font_size * 4/3; default 32) — the wrap and
           space-line-width metrics are derived from it

State lives in $XDG_RUNTIME_DIR/hypr-ddlc; a new lock is detected by a change of
the hyprlock PID and starts the dialog from the re-entry line
EOF
}

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
export HUIX

QUOTES="$HUIX/assets/monika-talk.txt"
REENTRY="$HUIX/assets/monika-reentry.txt"

TEXT_W="${TEXT_W:-1114}"
FONT_PX="${FONT_PX:-32}"
# Doki metrics relative to the font size: at 32px a glyph averages 15px, space 8px
AVG_ADV=$((FONT_PX * 15 / 32))
SPACE_ADV=$((FONT_PX / 4))
WRAP_CHARS=$((TEXT_W * 9 / (AVG_ADV * 10))) # wrap with ~10% margin
BOX_LINES=3                                 # lines in the text area

CPS=10 # typing speed, characters per second

LINE_MEAN=7 # pause after a line: Exp(1/7), sec
LINE_MIN=2
LINE_MAX=40

TOPIC_MEAN=60 # empty box between topics: Exp(1/60), sec
TOPIC_MIN=10
TOPIC_MAX=300

GLITCH_MEAN=120 # spontaneous glitches: Exp(1/120) intervals, sec
GLITCH_MIN=15
GLITCH_MAX=600
GLITCH_SHADER_SEC=1.2 # glitch shader duration
GLITCH_TEXT_MS=3600   # the text glitches longer than the shader

FADE_MS=600 # smooth fade-out of a line

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc"
STATE="$STATE_DIR/state"     # sourceable state-machine variables
TOPIC="$STATE_DIR/topic.txt" # unspoken lines of the current topic
CUR="$STATE_DIR/cur.txt"     # current line, already wrapped

# State defaults (first run = re-entry line right away)
phase=reentry
until_ms=0
reveal_ms=0
next_glitch_ms=0
glitch_until_ms=0
fail_chk=0
fail_ts=""
last_pid=""
last_talk=0    # index of the previous monika-talk.txt topic (0 = none)
last_reentry=0 # same for monika-reentry.txt

# Single list of state-machine fields: save/snapshot don't drift apart when a
# field is added
STATE_VARS=(phase until_ms reveal_ms next_glitch_ms glitch_until_ms fail_chk fail_ts last_pid last_talk last_reentry)

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

# Exponential random pause in ms: $1 = mean, $2 = min, $3 = max (sec)
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

# Random topic from file $1 -> $TOPIC; $2 is the index of this file's previous
# topic (0 = none), excluded from the draw so the same quote doesn't come up
# twice in a row. Prints the index of the chosen block. Blocks are separated by a
# blank line, lines with '#' are comments
new_topic() {
  : >"$TOPIC"
  awk -v seed="$(((RANDOM << 15) + RANDOM))" -v skip="${2:-0}" -v out="$TOPIC" '
    BEGIN { RS = ""; srand(seed) }
    { gsub(/(^|\n)#[^\n]*/, ""); sub(/^\n+/, ""); if ($0 != "") b[++n] = $0 }
    END {
      if (!n) exit
      # draw over n-1 options, shifting past the previous block
      if (n > 1 && skip >= 1 && skip <= n) {
        i = int(rand() * (n - 1)) + 1
        if (i >= skip) i++
      } else {
        i = int(rand() * n) + 1
      }
      print b[i] > out
      print i
    }
  ' "$1"
}

# Pop the first line of the topic into $CUR (wrapped); returns 1 if topic is empty
next_line() {
  local line
  line=$(head -n 1 "$TOPIC" 2>/dev/null || true)
  [[ -n "$line" ]] || return 1
  sed -i '1d' "$TOPIC"
  printf '%s\n' "${line//\[player\]/$USER}" |
    fold -s -w "$WRAP_CHARS" | sed 's/ *$//' >"$CUR"
}

# "Broken encoding": ~30% of characters are replaced with mojibake glyphs;
# regenerated on every call so the garbage "lives"
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

# Glitch the screen and text with one mechanism (password and Poisson stream)
# flash sleeps internally — fully detach it, otherwise hyprlock waits for EOF
fire_glitch() {
  glitch_until_ms=$((now_ms + GLITCH_TEXT_MS))
  nohup "$HUIX/scripts/screen-shader.sh" flash glitch "$GLITCH_SHADER_SEC" \
    </dev/null >/dev/null 2>&1 &
  disown
}

# Milliseconds without spawning date: EPOCHREALTIME = "sec.usec" (bash >= 5;
# the separator depends on the locale — strip both the dot and the comma)
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

# $1 is the topics file, $2 is the name of the state variable holding this file's
# previous topic index (updated to the chosen one)
start_topic() {
  local idx
  idx=$(new_topic "$1" "${!2}")
  [[ -z "$idx" ]] || printf -v "$2" '%s' "$idx"
  next_line
  start_typing
}

# Mojibake glyphs render in a fallback font with different line metrics — without
# anchors a glitch would change the texture height and the name would jump. The
# invisible edge glyphs keep the metrics (and, symmetrically, the centering) constant
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

  # Heavy checks (scanning /proc, the journal) — at most once per second
  if ((now_ms / 1000 > fail_chk)); then
    fail_chk=$((now_ms / 1000))

    # New lock (hyprlock PID change) -> dialog from the re-entry line
    local pid
    pid=$(pidof hyprlock 2>/dev/null) || pid=""
    pid=${pid%% *}
    if [[ -n "$pid" && "$pid" != "$last_pid" ]]; then
      last_pid="$pid"
      phase=reentry
    fi

    # Wrong password (hyprlock pam error in the journal) -> glitch
    local last
    last=$(journalctl -q -t hyprlock -S -5s -g 'authentication failure' \
      -o short-unix 2>/dev/null | tail -n 1 | cut -d' ' -f1) || true
    if [[ -n "$last" && "$last" != "$fail_ts" ]]; then
      fail_ts="$last"
      fire_glitch
    fi
  fi

  # Spontaneous glitches: a Poisson stream. 0 means not scheduled yet, then we
  # only assign the first interval, without firing
  if ((now_ms >= next_glitch_ms)); then
    ((next_glitch_ms > 0)) && fire_glitch
    next_glitch_ms=$((now_ms + $(exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX")))
  fi

  # State machine: reentry -> typing -> shown -> fadeout -> typing|gap
  case "$phase" in
  reentry)
    start_topic "$REENTRY" last_reentry
    ;;
  shown)
    if ((now_ms >= until_ms)); then
      phase=fadeout
      reveal_ms=$now_ms # start of the fade
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
      start_topic "$QUOTES" last_talk
    fi
    ;;
  esac

  # Frame: the whole line, the untyped tail as a transparent span (a Ren'Py
  # trick). The texture size stays constant for the whole life of the line
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

  # The frame is always BOX_LINES lines + a width-line of spaces: padding with
  # empty lines keeps the texture height constant, the space-line keeps its width
  # (a label has neither width nor a corner anchor, but with a constant texture
  # size halign center + valign bottom give a fixed top-left). Requires
  # text_trim=false in hyprlock
  local nl pad=""
  nl=${full//[!$'\n']/}
  for ((i = ${#nl} + 1; i < BOX_LINES; i++)); do pad+=$'\n'; done
  printf '%s%s\n%*s' "$body" "$pad" $((TEXT_W / SPACE_ADV)) ''

  # While typing the frame is a function of reveal_ms: the state doesn't change,
  # and on frequent polling there's no point writing it every tick
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
