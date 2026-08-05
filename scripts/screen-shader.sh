#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
screen-shader.sh — manager of Hyprland full-screen shaders and soft brightness

Commands:
  effect push <name>     ADD an effect to the stack (composited over the current ones)
  effect set <name>      REPLACE the stack with a single effect
  effect clear           clear the stack (turn all effects off)
  effect toggle <name>   in the stack — remove it; not — add it
  effect next|prev       replace the stack with the next/previous effect
  bright up|down         soft brightness ±5% (clamp 10..200%)
  bright reset           brightness 100%
  bright toggle          100% ↔ 50%
  bright set <0.10..2>   brightness exactly
  bright get             current brightness in percent (integer, for the UI)
  flash [-k] <name> [sec] effect for N seconds (default 1.0), then revert;
                         composited OVER the current stack (composition);
                         durable state is not touched;
                         -k — no-op if the stack is non-empty
  restore                re-read state and apply again
                         (exec on every Hyprland reload — the slot is runtime)
  status                 JSON for waybar (custom/shader)
  menu                   "<emoji> <label>|<name>" lines for the rofi picker
                         (active ones marked with an apply number: 01. 02. 03.)
  help                   this help

Effects STACK: every `effect push` adds a filter over the previous ones (the rofi
picker sends exactly push), and they compose into one shader until the stack is
cleared (`effect clear`, the "Normal" item in the picker, or SUPER+G). Hyprland has
one shader slot (decoration:screen_shader), so all effects in the stack plus
brightness are assembled into one generated GLSL. Effects that sample the texture
with an offset (crt/wave/glitch) go first in the chain (geometry), color filters
after; multiple geometric ones don't stack (the last overrides the previous ones)
— a limitation of the single slot. Each effect in scripts/shaders/<name>.frag
describes only the function vec3 effect(vec3 c, vec2 uv)

The choice (effect stack + brightness) is stored durably in ~/.local/state/huix/shader
— survives logout/reboot and isn't seen by the hourly sync; generated shaders are
ephemeral and live in $XDG_RUNTIME_DIR/hypr-shader
EOF
}

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Shader error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

notify_info() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "$1" "$2" || true
}

# The SIGRTMIN+N number is set by Nix (waybar/shader.nix) via WAYBAR_SHADER_SIGNAL
# SHADER_NO_SIGNAL suppresses the signal on restore at session start: the default
# action of an RT signal is to kill the process, and waybar may not have installed
# a handler yet
signal_waybar() {
  [[ -z "${SHADER_NO_SIGNAL:-}" ]] || return 0
  [[ -n "${WAYBAR_SHADER_SIGNAL:-}" ]] || return 0
  pkill -RTMIN+"$WAYBAR_SHADER_SIGNAL" waybar 2>/dev/null || true
}

require_env() {
  if [[ -z "${HUIX:-}" ]]; then
    notify_error "HUIX is not set"
    exit 1
  fi
}

require_env

SHADER_DIR="$HUIX/scripts/shaders"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-shader"
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/huix/shader"

# Order for cycling (effect next/prev). none first — this is "off"
EFFECTS=(none grayscale sepia invert warm cool vignette sharpen crt matrix posterize wave glitch jpeg)

# Animated effects (use the uniform time). They need damage tracking off,
# otherwise Hyprland doesn't redraw the frame
ANIMATED=(wave glitch matrix)

# Static effects that sample the texture with an OFFSET (curvature, distortion)
# With precise damage tracking (2) they read undrawn neighboring areas and "break"
# on fast screen changes. They need a redraw of the WHOLE monitor on any change
# (damage_tracking 1), but can sleep when idle — there's no animation
OFFSET=(crt jpeg sharpen)

# Emojis and labels for the waybar indicator (status) — the single source of truth
declare -A EMOJI=(
  [none]="🌈" [grayscale]="⚫" [sepia]="🟤" [invert]="🔄" [warm]="🌅"
  [cool]="❄️" [vignette]="🎯" [sharpen]="🔪" [crt]="📺" [matrix]="🟢"
  [posterize]="🎨" [wave]="🌊" [glitch]="📡" [jpeg]="💾"
)
declare -A LABEL=(
  [none]="Normal" [grayscale]="Grayscale" [sepia]="Sepia" [invert]="Invert"
  [warm]="Warm (night)" [cool]="Cool" [vignette]="Vignette" [sharpen]="Sharpen"
  [crt]="CRT" [matrix]="Matrix" [posterize]="Posterize" [wave]="Wave"
  [glitch]="Glitch" [jpeg]="JPEG"
)

mkdir -p "$STATE_DIR"

# Stack of active effects (in the order they were added). Empty = nothing applied
stack=()
bright="1.00"
# Hyprland does NOT recompile the shader if given the same path. So we write to
# alternating files (active-0/active-1) — the path always changes and the shader is
# guaranteed to be re-read (otherwise a brightness change with an active stack isn't
# applied)
slot=0

load_state() {
  stack=()
  if [[ -f "$STATE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE"
  fi
  # Migration from the old format (single effect=<name>)
  if [[ ${#stack[@]} -eq 0 && -n "${effect:-}" && "${effect:-none}" != "none" ]]; then
    stack=("$effect")
  fi
  unset effect 2>/dev/null || true
}

save_state() {
  mkdir -p "$(dirname "$STATE")"
  {
    printf 'stack=('
    printf '%s ' "${stack[@]}"
    printf ')\n'
    printf 'bright=%s\n' "$bright"
    printf 'slot=%s\n' "$slot"
  } >"$STATE"
}

# Index of an effect in EFFECTS (or -1)
effect_index() {
  local i
  for i in "${!EFFECTS[@]}"; do
    [[ "${EFFECTS[$i]}" == "$1" ]] && {
      printf '%s' "$i"
      return
    }
  done
  printf '%s' -1
}

in_list() {
  local item="$1"
  shift
  local x
  for x in "$@"; do
    [[ "$item" == "$x" ]] && return 0
  done
  return 1
}

# 1-based position of an effect in the stack (apply order) — prints the number and
# returns 0 if the effect is in the stack; otherwise returns 1 and prints nothing
stack_position() {
  local i=1 x
  for x in "${stack[@]}"; do
    [[ "$x" == "$1" ]] && {
      printf '%s' "$i"
      return 0
    }
    i=$((i + 1))
  done
  return 1
}

# The effect samples the texture itself (geometry/distortion) — such one goes first in the chain
samples_texture() {
  grep -q 'texture(' "$SHADER_DIR/$1.frag"
}

# Render mode by the effect list: take the most demanding one
#   animated   — there's animation (uniform time): damage 0 (draw every frame) + VFR off
#                (with VFR on Hyprland goes idle and the animation stutters);
#   fullstatic — there's a static one with offset sampling (curvature): damage 1 — on
#                any change redraw the whole monitor (otherwise precise damage breaks
#                the distorted sampling), but sleep when idle; VFR on;
#   default    — only per-pixel effects: default damage 2 + VFR (partial ok)
set_render_mode() {
  case "$1" in
  animated) hyprctl --batch "keyword debug:damage_tracking 0 ; keyword debug:vfr 0" >/dev/null ;;
  fullstatic) hyprctl --batch "keyword debug:damage_tracking 1 ; keyword debug:vfr 1" >/dev/null ;;
  *) hyprctl --batch "keyword debug:damage_tracking 2 ; keyword debug:vfr 1" >/dev/null ;;
  esac
}

render_mode_for() { # $@ = effect names
  local n
  for n in "$@"; do in_list "$n" "${ANIMATED[@]}" && {
    printf 'animated'
    return
  }; done
  for n in "$@"; do in_list "$n" "${OFFSET[@]}" && {
    printf 'fullstatic'
    return
  }; done
  printf 'default'
}

# Rename all top-level definitions of an effect body (effect, hash, …) with the
# suffix $2 — for composing several bodies in one shader without conflicts
rename_defs() { # $1 = file, $2 = suffix
  local names n args=()
  names=$(grep -oE '^(const )?(float|int|bool|vec[234]|mat[234]) +[A-Za-z_][A-Za-z0-9_]*' "$1" | awk '{ print $NF }')
  for n in $names; do
    args+=(-e "s/\b$n\b/${n}$2/g")
  done
  if [[ ${#args[@]} -eq 0 ]]; then
    cat "$1"
  else
    sed "${args[@]}" "$1"
  fi
}

# Assemble the full GLSL from a chain of effect bodies: $1 = output file, then a
# list of .frag files. The first body is used as is (function effect), the rest are
# renamed (effect_1, effect_2, …) and applied in turn to the result of the previous
# one. time in seconds since start: if any effect uses it, Hyprland redraws the
# frame continuously; otherwise the uniform is optimized out by the compiler
emit_shader() {
  local out="$1"
  shift
  local bodies=("$@") b i=0
  # Atomic write: write to a temp file, then mv — Hyprland won't see a half-written
  # shader on concurrent calls
  local tmp="${out}.tmp.$$"
  {
    printf '#version 300 es\n'
    printf 'precision highp float;\n\n'
    printf 'in vec2 v_texcoord;\n'
    printf 'uniform sampler2D tex;\n'
    printf 'uniform float time;\n'
    printf 'out vec4 fragColor;\n\n'
    printf '#define BRIGHTNESS %s\n\n' "$bright"
    for b in "${bodies[@]}"; do
      if [[ $i -eq 0 ]]; then
        cat "$b"
      else
        printf '\n'
        rename_defs "$b" "_$i"
      fi
      i=$((i + 1))
    done
    printf '\nvoid main() {\n'
    printf '    vec4 src = texture(tex, v_texcoord);\n'
    printf '    vec3 c = effect(src.rgb, v_texcoord);\n'
    i=1
    while [[ $i -lt ${#bodies[@]} ]]; do
      printf '    c = effect_%s(c, v_texcoord);\n' "$i"
      i=$((i + 1))
    done
    printf '    c *= BRIGHTNESS;\n'
    printf '    fragColor = vec4(c, src.a);\n'
    printf '}\n'
  } >"$tmp"
  mv -f "$tmp" "$out"
}

# Order the stack for the chain: geometric ones (sample the texture) first, color
# ones after. Prints one name per line
ordered_stack() {
  local e
  for e in "${stack[@]}"; do samples_texture "$e" && printf '%s\n' "$e"; done
  for e in "${stack[@]}"; do samples_texture "$e" || printf '%s\n' "$e"; done
}

apply() { # $1 (opt.) = transient: don't save state to durable state
  # Fully remove the shader if there are neither effects nor dimming
  if [[ ${#stack[@]} -eq 0 && "$bright" == "1.00" ]]; then
    set_render_mode default
    hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
    [[ "${1:-}" == "transient" ]] || save_state
    signal_waybar
    return
  fi

  # Body list in chain order. An empty stack with bright<1 is a single passthrough
  local bodies=() e
  if [[ ${#stack[@]} -eq 0 ]]; then
    bodies=("$SHADER_DIR/none.frag")
  else
    while IFS= read -r e; do
      [[ -f "$SHADER_DIR/$e.frag" ]] || {
        notify_error "Shader not found: $e"
        exit 1
      }
      bodies+=("$SHADER_DIR/$e.frag")
    done < <(ordered_stack)
  fi

  # Alternate the file so the path always changes and Hyprland re-reads the shader
  slot=$((1 - slot))
  local active="$STATE_DIR/active-$slot.frag"
  emit_shader "$active" "${bodies[@]}"

  set_render_mode "$(render_mode_for "${stack[@]}")"
  hyprctl keyword decoration:screen_shader "$active" >/dev/null
  [[ "${1:-}" == "transient" ]] || save_state
  signal_waybar
}

# Check the name and that the file exists
require_effect() {
  if [[ ! -f "$SHADER_DIR/$1.frag" ]]; then
    notify_error "Unknown effect: $1"
    exit 1
  fi
}

push_effect() {
  local name="$1"
  # "Normal" = reset the whole stack
  if [[ "$name" == "none" ]]; then
    clear_stack
    return
  fi
  require_effect "$name"
  if in_list "$name" "${stack[@]}"; then
    notify_info "Shader" "Already in the stack: ${LABEL[$name]} (・_・)"
    return
  fi
  stack+=("$name")
  apply
  notify_info "Shader" "Added: ${LABEL[$name]} · in the stack ${#stack[@]} （-＾〇＾-）"
}

set_single() {
  local name="$1"
  if [[ "$name" == "none" ]]; then
    clear_stack
    return
  fi
  require_effect "$name"
  stack=("$name")
  apply
  notify_info "Shader" "Effect: ${LABEL[$name]} （-＾〇＾-）"
}

toggle_effect() {
  local name="$1" e new=()
  # "Normal" = reset the whole stack, not adding none to the chain
  if [[ "$name" == "none" ]]; then
    clear_stack
    return
  fi
  require_effect "$name"
  if in_list "$name" "${stack[@]}"; then
    for e in "${stack[@]}"; do [[ "$e" == "$name" ]] || new+=("$e"); done
    stack=("${new[@]}")
    apply
    notify_info "Shader" "Removed: ${LABEL[$name]} · in the stack ${#stack[@]} (・_・)"
  else
    stack+=("$name")
    apply
    notify_info "Shader" "Added: ${LABEL[$name]} · in the stack ${#stack[@]} （-＾〇＾-）"
  fi
}

clear_stack() {
  stack=()
  apply
  notify_info "Shader" "Effects reset (★^O^★)"
}

cmd_effect() {
  load_state
  case "${1:-}" in
  push | add) push_effect "${2:?effect name required}" ;;
  set) set_single "${2:?effect name required}" ;;
  toggle | off-or) toggle_effect "${2:?effect name required}" ;;
  clear | off | none) clear_stack ;;
  next | prev)
    local cur="none" idx step n
    [[ ${#stack[@]} -gt 0 ]] && cur="${stack[-1]}"
    idx=$(effect_index "$cur")
    n=${#EFFECTS[@]}
    if [[ "$1" == "next" ]]; then step=1; else step=$((n - 1)); fi
    set_single "${EFFECTS[$(((idx + step) % n))]}"
    ;;
  *)
    notify_error "Usage: effect push|set|toggle|clear|next|prev <name>"
    exit 1
    ;;
  esac
}

cmd_bright() {
  # flock -n: on fast scrolling waybar sends dozens of calls in parallel. A
  # blocking flock queues them → the queue piles up → a hang. Non-blocking: if
  # another instance is already running — exit silently, and the atomic write in
  # emit_shader guarantees Hyprland won't see a broken shader even without serialization
  exec 8>"$STATE_DIR/bright.lock"
  flock -n 8 || exit 0
  load_state
  local step="0.05"
  case "${1:-}" in
  up) bright=$(awk -v b="$bright" -v s="$step" 'BEGIN{v=b+s; if(v>2)v=2;    printf "%.2f", v}') ;;
  down) bright=$(awk -v b="$bright" -v s="$step" 'BEGIN{v=b-s; if(v<0.1)v=0.1; printf "%.2f", v}') ;;
  reset) bright="1.00" ;;
  toggle) if [[ "$bright" == "1.00" ]]; then bright="0.50"; else bright="1.00"; fi ;;
  set) bright=$(awk -v b="${2:?value required}" 'BEGIN{v=b; if(v>2)v=2; if(v<0.1)v=0.1; printf "%.2f", v}') ;;
  get)
    awk -v b="$bright" 'BEGIN{printf "%d", b*100}'
    return 0
    ;;
  *)
    notify_error "Usage: bright up|down|reset|toggle|set <0.10..2.00> | get"
    exit 1
    ;;
  esac
  apply
  # Synchronous tag: while holding the key one popup updates instead of spamming the feed
  command -v notify-send >/dev/null 2>&1 && notify-send -u low \
    -h string:x-canonical-private-synchronous:huix-bright \
    "Brightness" "Brightness: $(awk -v b="$bright" 'BEGIN{printf "%d", b*100}')% ☀" || true
}

# A temporary effect for N seconds, COMPOSITED over the current stack. Durable
# state is not touched — a crash mid-flash breaks nothing. Writes to a separate
# flash.frag, not touching the active-0/1 slots: the restore path after flash is
# guaranteed to differ, Hyprland re-reads the shader. Concurrent flashes are
# suppressed by flock; -k — exit silently if the stack is non-empty
cmd_flash() {
  SHADER_NO_SIGNAL=1
  local keep=""
  if [[ "${1:-}" == "-k" ]]; then
    keep=1
    shift
  fi
  local name="${1:?effect name required}" dur="${2:-1.0}"
  require_effect "$name"

  exec 9>"$STATE_DIR/.flash.lock"
  flock -n 9 || exit 0

  load_state
  [[ -n "$keep" && ${#stack[@]} -gt 0 ]] && exit 0

  # The flash body first (usually samples the texture itself — glitch/wave); from
  # the stack we take into the chain only color ones (not sampling the texture) —
  # otherwise they'd overwrite the flash result (a proper composition of several
  # geometries needs multi-pass rendering, and Hyprland has one slot)
  local bodies=("$SHADER_DIR/$name.frag") e
  for e in "${stack[@]}"; do
    samples_texture "$e" || bodies+=("$SHADER_DIR/$e.frag")
  done
  local file="$STATE_DIR/flash.frag"
  emit_shader "$file" "${bodies[@]}"

  # Render mode/cursor — over the whole pair (flash + stack)
  set_render_mode "$(render_mode_for "$name" "${stack[@]}")"

  hyprctl keyword decoration:screen_shader "$file" >/dev/null
  sleep "$dur"
  load_state
  apply
}

cmd_restore() {
  # Don't signal waybar at session start (see signal_waybar); the script exits
  # right away, so setting the flag globally is safe
  SHADER_NO_SIGNAL=1
  load_state
  apply
}

# JSON for waybar (custom/shader): emojis of all stack effects + brightness percent
cmd_status() {
  load_state
  local pct emoji="" labels="" e class
  pct=$(awk -v b="$bright" 'BEGIN{printf "%d", b * 100}')
  for e in "${stack[@]}"; do
    emoji+="${EMOJI[$e]:-🎬}"
    labels+="${LABEL[$e]:-$e} + "
  done
  labels="${labels% + }"
  if [[ ${#stack[@]} -gt 1 ]]; then class="stack"; elif [[ ${#stack[@]} -eq 1 ]]; then class="${stack[0]}"; else class="dim"; fi

  if [[ ${#stack[@]} -eq 0 && "$bright" == "1.00" ]]; then
    # Nothing active — the module hides (empty text)
    printf '{"text":"","tooltip":"","class":"off"}\n'
  elif [[ ${#stack[@]} -eq 0 ]]; then
    printf '{"text":"🔅 %s%%","tooltip":"Brightness %s%%","class":"dim"}\n' "$pct" "$pct"
  elif [[ "$bright" == "1.00" ]]; then
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$emoji" "$labels" "$class"
  else
    printf '{"text":"%s %s%%","tooltip":"%s · brightness %s%%","class":"%s"}\n' \
      "$emoji" "$pct" "$labels" "$pct" "$class"
  fi
}

# List "<emoji> <label>|<value>" in EFFECTS order — the single source of truth for
# the rofi picker (rofi-shader.sh reads exactly this). Active ones in the stack are
# marked with an apply number in the "01. " format (stack order = the order in
# which effects were added), to see the accumulated composition and its order
cmd_menu() {
  load_state
  local e mark pos
  for e in "${EFFECTS[@]}"; do
    if [[ "$e" != "none" ]] && pos=$(stack_position "$e"); then
      mark=$(printf '%02d. ' "$pos")
    else
      mark=""
    fi
    printf '%s%s %s|%s\n' "$mark" "${EMOJI[$e]}" "${LABEL[$e]}" "$e"
  done
}

# Full reset: effects + brightness in one apply (for waybar RMB)
cmd_reset_all() {
  load_state
  stack=()
  bright="1.00"
  apply
  notify_info "Shader" "Effects and brightness reset (★^O^★)"
}

case "${1:-}" in
effect)
  shift
  cmd_effect "$@"
  ;;
bright)
  shift
  cmd_bright "$@"
  ;;
flash)
  shift
  cmd_flash "$@"
  ;;
restore) cmd_restore ;;
reset-all) cmd_reset_all ;;
status) cmd_status ;;
menu) cmd_menu ;;
help | -h | --help) usage ;;
*)
  usage >&2
  notify_error "Usage: screen-shader.sh effect|bright|reset-all|restore|status|menu|help"
  exit 1
  ;;
esac
