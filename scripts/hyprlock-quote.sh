#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
hyprlock-quote.sh — Monika's dialog for the DDLC lock screen

Modes:
  lock   run a lock: start hyprlock and animate its dialog until it exits.
         This is hypridle's lock_cmd, and every lock path (SUPER+F12,
         rofi-power.sh, the idle timeout) funnels through it
  help   this help

Rendering is push, not polling. The two dialog labels in hyprlock.conf are
declared cmd[update:0:1] — armed for an hour, refreshed only when hyprlock gets
SIGUSR2 — and do nothing but `cat` the files this loop writes. The loop signals
only on the ticks where the rendered text actually changed, and between lines it
sleeps outright, so a lock screen standing still costs nothing

The loop runs in the foreground with hyprlock as its child: no daemon to reap,
and lock_cmd blocks for exactly the duration of the lock. It never kills
hyprlock — dying must not unlock the screen

Typing is a Ren'Py trick: every frame renders the whole line, and the tail not
yet "typed" is hidden in a transparent span. The texture size stays constant for
the whole life of the line, and the text is pinned in place without any font
measurements; line wrapping is just a fold by character count

Glitches are a single mechanism for a wrong password and spontaneous firings (a
Poisson stream): the screen glitches via `screen-shader.sh flash glitch`
(composited over the active effect), at the same time the name and text are
garbled with a "broken encoding"; the text glitches longer than the shader. A
wrong password arrives as a line from a `journalctl -f` follower, which is also
what the loop sleeps on — so it reacts at once without polling the journal

Geometry is set by hyprlock.nix through the environment:
  TEXT_W     width of the box text area, px (default 1114)
  FONT_PX    line font size, px (font_size * 4/3; default 32) — the wrap and
             space-line-width metrics are derived from it
  STATE_DIR  where the rendered frame/name files live; hyprlock.nix points the
             labels at the same path

State is plain shell variables for the lifetime of the lock, so a fresh run is
by definition a fresh lock and starts the dialog from the re-entry line
EOF
}

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
export HUIX

QUOTES="$HUIX/assets/monika-talk.txt"
REENTRY="$HUIX/assets/monika-reentry.txt"

TEXT_W="${TEXT_W:-1114}"
FONT_PX="${FONT_PX:-32}"
STATE_DIR="${STATE_DIR:-${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc}"

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

# Tick as fast as the pixels actually move, never faster: one char per 1000/CPS
# while typing, but the alpha ramp and the mojibake churn need every frame
TYPE_MS=$((1000 / CPS))
ANIM_MS=33
# Ceiling on a sleep: an unlock is only noticed on the next wake, and SIGCHLD does
# not interrupt read -t, so this is what bounds the lag. An idle wake forks nothing
IDLE_CAP_MS=1000

FRAME_FILE="$STATE_DIR/frame"
NAME_FILE="$STATE_DIR/name"

# Mojibake glyphs render in a fallback font with different line metrics — without
# anchors a glitch would change the texture height and the name would jump. The
# invisible edge glyphs keep the metrics (and, symmetrically, the centering) constant
NAME_ANCHOR='<span alpha="1">�Жð</span>'
GLYPHS=(Ã Ð Ñ Â Ø Þ ß ð þ ¤ ¥ § ¶ ¿ ¬ Œ ž Æ é ö ъ Ж �)

phase=reentry
until_ms=0
reveal_ms=0
next_glitch_ms=0
glitch_until_ms=0
# both are read and written indirectly, by name, from start_topic
# shellcheck disable=SC2034
last_talk=0 # index of the previous monika-talk.txt topic (0 = none)
# shellcheck disable=SC2034
last_reentry=0 # same for monika-reentry.txt
topic_lines=() # unspoken lines of the current topic
cur=""         # current line, already wrapped
frame_prev=$'\0'
name_prev=$'\0'
now=0

# Milliseconds without spawning date: EPOCHREALTIME = "sec.usec" (bash >= 5;
# the separator depends on the locale — strip both the dot and the comma)
set_now() {
  local t=${EPOCHREALTIME//[.,]/}
  now=${t:0:-3}
}

# Exponential random pause in ms -> $exp_v: $1 = mean, $2 = min, $3 = max (sec)
exp_ms() {
  exp_v=$(awk -v m="$1" -v lo="$2" -v hi="$3" -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      d = -m * log(1 - rand())
      if (d < lo) d = lo
      if (d > hi) d = hi
      printf "%d", d * 1000
    }')
}

esc() {
  local s=$1
  s=${s//&/&amp;}
  s=${s//</&lt;}
  s=${s//>/&gt;}
  esc_v=$s
}

# "Broken encoding" -> $glitch_v: ~30% of characters are replaced with mojibake
# glyphs; regenerated on every call so the garbage "lives". Pure bash — at 33 ms
# a fork per frame is exactly what this rewrite exists to avoid
glitch_text() {
  local s=$1 out="" c i
  for ((i = 0; i < ${#s}; i++)); do
    c=${s:i:1}
    if [[ $c != " " && $c != $'\n' ]] && ((RANDOM % 10 < 3)); then
      out+=${GLYPHS[RANDOM % ${#GLYPHS[@]}]}
    else
      out+=$c
    fi
  done
  glitch_v=$out
}

# Random topic from file $1: prints the chosen block's index, then the block
# itself. $2 is the index of this file's previous topic (0 = none), excluded from
# the draw so the same quote doesn't come up twice in a row. Blocks are separated
# by a blank line, lines with '#' are comments
draw_topic() {
  awk -v seed="$(((RANDOM << 15) + RANDOM))" -v skip="${2:-0}" '
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
      print i
      print b[i]
    }
  ' "$1"
}

# Pop the first line of the topic into $cur (wrapped); returns 1 if topic is empty
next_line() {
  ((${#topic_lines[@]})) || return 1
  local line=${topic_lines[0]}
  topic_lines=("${topic_lines[@]:1}")
  cur=$(printf '%s\n' "${line//\[player\]/$USER}" |
    fold -s -w "$WRAP_CHARS" | sed 's/ *$//')
}

start_typing() {
  phase=typing
  reveal_ms=$now
}

# $1 is the topics file, $2 is the name of the variable holding this file's
# previous topic index (updated to the chosen one)
start_topic() {
  local out
  mapfile -t out < <(draw_topic "$1" "${!2}")
  if ((${#out[@]})); then
    printf -v "$2" '%s' "${out[0]}"
    topic_lines=("${out[@]:1}")
  fi
  next_line || true
  start_typing
}

fire_glitch() {
  glitch_until_ms=$((now + GLITCH_TEXT_MS))
  "$HUIX/scripts/screen-shader.sh" flash glitch "$GLITCH_SHADER_SEC" \
    </dev/null >/dev/null 2>&1 &
}

# Advance the state machine: reentry -> typing -> shown -> fadeout -> typing|gap.
# The typing -> shown edge is in build_frame, where the revealed length is known
advance() {
  case "$phase" in
  reentry)
    start_topic "$REENTRY" last_reentry
    ;;
  shown)
    if ((now >= until_ms)); then
      phase=fadeout
      reveal_ms=$now # start of the fade
      until_ms=$((now + FADE_MS))
    fi
    ;;
  fadeout)
    if ((now >= until_ms)); then
      if next_line; then
        start_typing
      else
        phase=gap
        exp_ms "$TOPIC_MEAN" "$TOPIC_MIN" "$TOPIC_MAX"
        until_ms=$((now + exp_v))
      fi
    fi
    ;;
  gap)
    if ((now >= until_ms)); then
      start_topic "$QUOTES" last_talk
    fi
    ;;
  esac
}

# Frame -> $frame_v: the whole line, the untyped tail as a transparent span (a
# Ren'Py trick). The texture size stays constant for the whole life of the line
build_frame() {
  local full="" n=0 fade_alpha=65535 body nl pad="" i
  if [[ "$phase" != "gap" ]]; then
    full=$cur
    case "$phase" in
    typing)
      n=$(((now - reveal_ms) * CPS / 1000))
      if ((n >= ${#full})); then
        phase=shown
        exp_ms "$LINE_MEAN" "$LINE_MIN" "$LINE_MAX"
        until_ms=$((now + exp_v))
        n=${#full}
      fi
      ;;
    fadeout)
      n=${#full}
      fade_alpha=$((65535 - 65535 * (now - reveal_ms) / FADE_MS))
      ((fade_alpha >= 1)) || fade_alpha=1
      ;;
    *)
      n=${#full}
      ;;
    esac
    if ((now < glitch_until_ms)); then
      glitch_text "$full"
      full=$glitch_v
    fi
  fi

  esc "${full:0:n}"
  body=$esc_v
  if ((n < ${#full})); then
    esc "${full:n}"
    body+="<span alpha=\"1\">$esc_v</span>"
  fi
  if ((fade_alpha < 65535)); then
    body="<span alpha=\"$fade_alpha\">$body</span>"
  fi

  # The frame is always BOX_LINES lines + a width-line of spaces: padding with
  # empty lines keeps the texture height constant, the space-line keeps its width
  # (a label has neither width nor a corner anchor, but with a constant texture
  # size halign center + valign bottom give a fixed top-left). Requires
  # text_trim=false in hyprlock
  nl=${full//[!$'\n']/}
  for ((i = ${#nl} + 1; i < BOX_LINES; i++)); do pad+=$'\n'; done
  printf -v frame_v '%s%s\n%*s' "$body" "$pad" $((TEXT_W / SPACE_ADV)) ''
}

build_name() {
  local name="Monika"
  if ((now < glitch_until_ms)); then
    glitch_text "$name"
    name=$glitch_v
  fi
  name_v="$NAME_ANCHOR$name$NAME_ANCHOR"
}

# Write atomically (a label may be reading) and wake hyprlock only on a real
# change — this is the whole budget of the lock screen
publish() {
  local changed=0
  if [[ "$frame_v" != "$frame_prev" ]]; then
    printf '%s' "$frame_v" >"$FRAME_FILE.tmp"
    mv "$FRAME_FILE.tmp" "$FRAME_FILE"
    frame_prev=$frame_v
    changed=1
  fi
  if [[ "$name_v" != "$name_prev" ]]; then
    printf '%s' "$name_v" >"$NAME_FILE.tmp"
    mv "$NAME_FILE.tmp" "$NAME_FILE"
    name_prev=$name_v
    changed=1
  fi
  ((changed)) && kill -USR2 "$hyprlock_pid" 2>/dev/null
  return 0
}

# Milliseconds until the next visible change -> $tick_v
next_tick_ms() {
  local t
  case "$phase" in
  typing) t=$((now + TYPE_MS)) ;;
  fadeout) t=$((now + ANIM_MS)) ;;
  *) t=$until_ms ;;
  esac
  ((next_glitch_ms < t)) && t=$next_glitch_ms
  ((glitch_until_ms > now && now + ANIM_MS < t)) && t=$((now + ANIM_MS))
  ((t > now + IDLE_CAP_MS)) && t=$((now + IDLE_CAP_MS))
  ((t < now)) && t=$now
  tick_v=$((t - now))
}

# Sleep on the journal follower: a wrong password wakes us instantly, everything
# else is a plain timeout. Falls back to sleep(1) if the follower ever dies, so a
# closed fd can never turn this into a spin
wait_ms() {
  local to rc=0
  printf -v to '%d.%03d' $(($1 / 1000)) $(($1 % 1000))
  if [[ -n "$journal_fd" ]]; then
    read -r -t "$to" -u "$journal_fd" _ || rc=$?
    if ((rc == 0)); then
      fire_glitch
    elif ((rc > 0 && rc <= 128)); then
      exec {journal_fd}<&- || true
      journal_fd=""
    fi
  else
    sleep "$to"
  fi
}

# A zombie still answers `kill -0`, /proc does not lie. No fork either.
# stderr is redirected first: a missing stat file is the shell's message, not read's
hyprlock_alive() {
  local state
  read -r _ _ state _ 2>/dev/null < "/proc/$hyprlock_pid/stat" || return 1
  [[ "$state" != "Z" ]]
}

cmd_lock() {
  mkdir -p "$STATE_DIR"
  # the labels cat these on hyprlock's very first render
  : >"$FRAME_FILE"
  : >"$NAME_FILE"

  hyprlock &
  hyprlock_pid=$!

  coproc JOURNAL {
    journalctl -f -n 0 -q -t hyprlock -g 'authentication failure' -o cat
  }
  journal_fd=${JOURNAL[0]}
  trap 'kill "$JOURNAL_PID" 2>/dev/null || true' EXIT

  while hyprlock_alive; do
    set_now

    # Spontaneous glitches: a Poisson stream. 0 means not scheduled yet, then we
    # only assign the first interval, without firing
    if ((now >= next_glitch_ms)); then
      ((next_glitch_ms > 0)) && fire_glitch
      exp_ms "$GLITCH_MEAN" "$GLITCH_MIN" "$GLITCH_MAX"
      next_glitch_ms=$((now + exp_v))
    fi

    advance
    build_frame
    build_name
    publish

    next_tick_ms
    wait_ms "$tick_v"
  done

  wait "$hyprlock_pid" 2>/dev/null || true
}

case "${1:-lock}" in
lock) cmd_lock ;;
help | -h | --help) usage ;;
*)
  usage >&2
  exit 1
  ;;
esac
