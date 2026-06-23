#!/usr/bin/env bash

# Единый менеджер полноэкранных шейдеров Hyprland.
#
# Hyprland держит только ОДИН слот шейдера (decoration:screen_shader), поэтому
# цветовой эффект и затемнение нельзя включить независимо — мы их композируем.
# Каждый эффект в scripts/shaders/<name>.frag описывает только функцию
#   vec3 effect(vec3 c, vec2 uv)
# а этот скрипт собирает из неё + уровня яркости финальный шейдер и применяет его.
#
# Состояние (выбранный эффект и яркость) хранится в runtime-каталоге, а не в
# git-дереве, чтобы hourly-sync его не закоммитил.
#
# Использование:
#   screen-shader.sh effect set <name>      — поставить эффект
#   screen-shader.sh effect toggle <name>   — переключить эффект <-> none
#   screen-shader.sh effect next|prev       — листать эффекты по кругу
#   screen-shader.sh bright up|down         — яркость ±0.10 (кламп 0.10..1.00)
#   screen-shader.sh bright reset           — яркость = 1.00
#   screen-shader.sh bright set <0.10..1.00>

set -euo pipefail

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Shader error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi
  printf '%s\n' "$1" >&2
}

notify_info() {
  command -v notify-send >/dev/null 2>&1 && notify-send -u low "$1" "$2" || true
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
STATE="$STATE_DIR/state"

# Порядок для листания (effect next/prev). none первым — это «выключено».
EFFECTS=(none grayscale sepia invert warm cool vignette crt matrix posterize wave glitch)

# Анимированные эффекты (используют uniform time). Им нужен выключенный
# damage tracking, иначе Hyprland не перерисовывает кадр.
ANIMATED=(wave glitch matrix)

# Статичные эффекты, которые сэмплят текстуру со СМЕЩЕНИЕМ (кривизна, искажение).
# При частичном damage tracking они читают непереисованные соседние области и
# «ломаются» на быстрых изменениях экрана. Им нужна полная перерисовка
# (damage_tracking 0), но VFR можно оставить — анимации нет.
OFFSET=(crt)

mkdir -p "$STATE_DIR"

effect="none"
bright="1.00"
# Hyprland НЕ перекомпилирует шейдер, если задать тот же путь. Поэтому пишем
# в чередующиеся файлы (active-0/active-1) — путь всегда меняется и шейдер
# гарантированно перечитывается (иначе смена яркости при активном эффекте
# не применяется).
slot=0

load_state() {
  if [[ -f "$STATE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE"
  fi
}

save_state() {
  printf 'effect=%s\nbright=%s\nslot=%s\n' "$effect" "$bright" "$slot" >"$STATE"
}

# Индекс эффекта в EFFECTS (или -1).
effect_index() {
  local i
  for i in "${!EFFECTS[@]}"; do
    [[ "${EFFECTS[$i]}" == "$1" ]] && { printf '%s' "$i"; return; }
  done
  printf '%s' -1
}

in_list() {
  local item="$1"; shift
  local x
  for x in "$@"; do
    [[ "$item" == "$x" ]] && return 0
  done
  return 1
}

# Режим отрисовки по типу эффекта:
#   animated   — анимация (uniform time): полный damage + VFR off (рисуем каждый
#                кадр; при включённом VFR Hyprland уходит в idle и анимация дёргается);
#   fullstatic — статичный, но со смещённой выборкой (кривизна): полный damage +
#                VFR on (перерисовываем весь экран, но только при изменениях —
#                иначе частичный damage ломает искажённую выборку);
#   default    — попиксельный эффект: дефолтные damage + VFR (частичный damage ок).
set_render_mode() {
  case "$1" in
    animated)   hyprctl --batch "keyword debug:damage_tracking 0 ; keyword debug:vfr 0" >/dev/null ;;
    fullstatic) hyprctl --batch "keyword debug:damage_tracking 0 ; keyword debug:vfr 1" >/dev/null ;;
    *)          hyprctl --batch "keyword debug:damage_tracking 2 ; keyword debug:vfr 1" >/dev/null ;;
  esac
}

render_mode_for() {
  if in_list "$1" "${ANIMATED[@]}"; then
    printf 'animated'
  elif in_list "$1" "${OFFSET[@]}"; then
    printf 'fullstatic'
  else
    printf 'default'
  fi
}

apply() {
  # Полностью убираем шейдер, если ни эффекта, ни затемнения нет.
  if [[ "$effect" == "none" && "$bright" == "1.00" ]]; then
    set_render_mode default
    hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
    return
  fi

  local body="$SHADER_DIR/$effect.frag"
  if [[ ! -f "$body" ]]; then
    notify_error "Shader not found: $body"
    exit 1
  fi

  # Чередуем файл, чтобы путь всегда менялся и Hyprland перечитал шейдер.
  slot=$((1 - slot))
  local active="$STATE_DIR/active-$slot.frag"

  {
    printf '#version 300 es\n'
    printf 'precision highp float;\n\n'
    printf 'in vec2 v_texcoord;\n'
    printf 'uniform sampler2D tex;\n'
    # time в секундах от старта. Если эффект его реально использует, Hyprland
    # начинает перерисовывать кадр непрерывно (анимация); для статичных
    # шейдеров uniform вычищается компилятором и перерисовки нет.
    printf 'uniform float time;\n'
    printf 'out vec4 fragColor;\n\n'
    printf '#define BRIGHTNESS %s\n\n' "$bright"
    cat "$body"
    printf '\nvoid main() {\n'
    printf '    vec4 src = texture(tex, v_texcoord);\n'
    printf '    vec3 c = effect(src.rgb, v_texcoord);\n'
    printf '    c *= BRIGHTNESS;\n'
    printf '    fragColor = vec4(c, src.a);\n'
    printf '}\n'
  } >"$active"

  set_render_mode "$(render_mode_for "$effect")"
  hyprctl keyword decoration:screen_shader "$active" >/dev/null
  save_state
}

set_effect() {
  local name="$1"
  if [[ ! -f "$SHADER_DIR/$name.frag" ]]; then
    notify_error "Unknown effect: $name"
    exit 1
  fi
  effect="$name"
  save_state
  apply
  [[ "$name" == "none" ]] \
    && notify_info "Shader" "Эффект выключен (★^O^★)" \
    || notify_info "Shader" "Эффект: $name （-＾〇＾-）"
}

cmd_effect() {
  load_state
  case "${1:-}" in
    set)    set_effect "${2:?effect name required}" ;;
    toggle) [[ "$effect" == "${2:?effect name required}" ]] && set_effect none || set_effect "$2" ;;
    next|prev)
      local idx step n
      idx=$(effect_index "$effect")
      n=${#EFFECTS[@]}
      [[ "$1" == "next" ]] && step=1 || step=$((n - 1))
      set_effect "${EFFECTS[$(((idx + step) % n))]}"
      ;;
    *) notify_error "Usage: effect set|toggle <name> | next | prev"; exit 1 ;;
  esac
}

cmd_bright() {
  load_state
  local step="0.10"
  case "${1:-}" in
    up)    bright=$(awk -v b="$bright" -v s="$step" 'BEGIN{v=b+s; if(v>1)v=1;    printf "%.2f", v}') ;;
    down)  bright=$(awk -v b="$bright" -v s="$step" 'BEGIN{v=b-s; if(v<0.1)v=0.1; printf "%.2f", v}') ;;
    reset) bright="1.00" ;;
    set)   bright=$(awk -v b="${2:?value required}" 'BEGIN{v=b; if(v>1)v=1; if(v<0.1)v=0.1; printf "%.2f", v}') ;;
    *) notify_error "Usage: bright up|down|reset|set <0.10..1.00>"; exit 1 ;;
  esac
  save_state
  apply
  notify_info "Brightness" "Яркость: $(awk -v b="$bright" 'BEGIN{printf "%d", b*100}')% ☀"
}

case "${1:-}" in
  effect) shift; cmd_effect "$@" ;;
  bright) shift; cmd_bright "$@" ;;
  *) notify_error "Usage: screen-shader.sh effect|bright ..."; exit 1 ;;
esac
