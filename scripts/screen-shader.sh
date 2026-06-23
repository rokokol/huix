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
#   screen-shader.sh effect off-or <name>   — есть эффект -> выкл; нет -> включить <name>
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

# Пинаем waybar перечитать индикатор шейдера (модуль слушает SIGRTMIN+N). Номер
# сигнала задаёт Nix (waybar-pc.nix) и кладёт в WAYBAR_SHADER_SIGNAL — единый
# источник правды. Не задан (ноут без индикатора / вне сессии) — просто не шлём.
#
# SHADER_NO_SIGNAL гасит сигнал при restore на старте сессии: SIGRTMIN+N по
# умолчанию ЗАВЕРШАЕТ процесс, и если послать его пока waybar ещё не успел
# установить обработчик (гонка autostart), waybar убивается. На старте сигнал и
# не нужен — waybar сам прочитает статус своим exec-ом при запуске.
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
# Генерируемые active-*.frag — эфемерны, держим в рантайме.
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-shader"
# Выбор эффекта/яркости — durable (как тема): переживает логаут и ребут, чтобы
# шейдер не слетал на старте новой сессии. Не в git-дереве (hourly-sync не трогает).
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/huix/shader"

# Порядок для листания (effect next/prev). none первым — это «выключено».
EFFECTS=(none grayscale sepia invert warm cool vignette crt matrix posterize wave glitch)

# Анимированные эффекты (используют uniform time). Им нужен выключенный
# damage tracking, иначе Hyprland не перерисовывает кадр.
ANIMATED=(wave glitch matrix)

# Статичные эффекты, которые сэмплят текстуру со СМЕЩЕНИЕМ (кривизна, искажение).
# При точном damage tracking (2) они читают непереисованные соседние области и
# «ломаются» на быстрых изменениях экрана. Им нужна перерисовка ВСЕГО монитора
# при любом изменении (damage_tracking 1), но в простое можно спать — анимации нет.
OFFSET=(crt)

# Эффекты, которые двигают пиксели ГЕОМЕТРИЧЕСКИ (кривизна/искажение). Для них
# включаем ПРОГРАММНЫЙ курсор, чтобы он проходил через шейдер вместе с экраном:
# аппаратный курсор рисуется оверлеем мимо шейдера и не совпадает с искажённым
# контентом (из-за чего клики у краёв уезжают). Для остальных — аппаратный (быстрее).
WARP=(crt wave glitch)

# Эмодзи и подписи для индикатора в waybar (status) — один источник правды.
declare -A EMOJI=(
  [none]="🌈" [grayscale]="⚫" [sepia]="🟤" [invert]="🔄" [warm]="🌅"
  [cool]="❄️" [vignette]="🎯" [crt]="📺" [matrix]="🟢" [posterize]="🎨"
  [wave]="🌊" [glitch]="📡"
)
declare -A LABEL=(
  [none]="Обычный" [grayscale]="Чёрно-белый" [sepia]="Сепия" [invert]="Негатив"
  [warm]="Тёплый (ночь)" [cool]="Холодный" [vignette]="Виньетка" [crt]="Кинескоп"
  [matrix]="Матрица" [posterize]="Постеризация" [wave]="Волна" [glitch]="Глитч"
)

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
  mkdir -p "$(dirname "$STATE")"
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
#   animated   — анимация (uniform time): damage 0 (рисуем каждый кадр) + VFR off
#                (при включённом VFR Hyprland уходит в idle и анимация дёргается);
#   fullstatic — статичный, но со смещённой выборкой (кривизна): damage 1 — при
#                любом изменении перерисовываем весь монитор (иначе точный damage
#                ломает искажённую выборку), но в простое спим; VFR on;
#   default    — попиксельный эффект: дефолтные damage 2 + VFR (частичный damage ок).
set_render_mode() {
  case "$1" in
    animated)   hyprctl --batch "keyword debug:damage_tracking 0 ; keyword debug:vfr 0" >/dev/null ;;
    fullstatic) hyprctl --batch "keyword debug:damage_tracking 1 ; keyword debug:vfr 1" >/dev/null ;;
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

# Программный курсор для искажающих эффектов (см. WARP) — иначе аппаратный курсор
# идёт мимо шейдера. На NVIDIA «программный курсор» = воркэраунд аппаратного, так
# что это безопасная сторона; аппаратный (false) — текущий дефолт.
set_cursor_for() {
  if in_list "$1" "${WARP[@]}"; then
    hyprctl keyword cursor:no_hardware_cursors true >/dev/null
  else
    hyprctl keyword cursor:no_hardware_cursors false >/dev/null
  fi
}

apply() {
  # Полностью убираем шейдер, если ни эффекта, ни затемнения нет.
  if [[ "$effect" == "none" && "$bright" == "1.00" ]]; then
    set_render_mode default
    set_cursor_for none
    hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
    signal_waybar
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
  set_cursor_for "$effect"
  hyprctl keyword decoration:screen_shader "$active" >/dev/null
  save_state
  signal_waybar
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
  if [[ "$name" == "none" ]]; then
    notify_info "Shader" "Эффект выключен (★^O^★)"
  else
    notify_info "Shader" "Эффект: $name （-＾〇＾-）"
  fi
}

cmd_effect() {
  load_state
  case "${1:-}" in
    set)    set_effect "${2:?effect name required}" ;;
    off-or)
      # Любой активный эффект -> выключить; если эффекта нет -> включить <name>.
      if [[ "$effect" == "none" ]]; then
        set_effect "${2:?effect name required}"
      else
        set_effect none
      fi
      ;;
    next|prev)
      local idx step n
      idx=$(effect_index "$effect")
      n=${#EFFECTS[@]}
      if [[ "$1" == "next" ]]; then step=1; else step=$((n - 1)); fi
      set_effect "${EFFECTS[$(((idx + step) % n))]}"
      ;;
    *) notify_error "Usage: effect set|off-or <name> | next | prev"; exit 1 ;;
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

# Перечитать состояние и заново применить шейдер. Нужно после reload Hyprland
# (в т.ч. при nixos-rebuild) — screen_shader живёт только в рантайме и слетает,
# поэтому hyprland.conf зовёт это через `exec` на каждом reload.
cmd_restore() {
  # На старте сессии не сигналим waybar (см. signal_waybar) — иначе ранний
  # SIGRTMIN+N убьёт ещё не готовый waybar. Скрипт тут же завершается, так что
  # глобальная установка флага безопасна.
  SHADER_NO_SIGNAL=1
  load_state
  apply
}

# JSON для waybar (custom/shader): эмодзи эффекта + процент яркости.
cmd_status() {
  load_state
  local pct emoji
  pct=$(awk -v b="$bright" 'BEGIN{printf "%d", b * 100}')
  emoji="${EMOJI[$effect]:-🎬}"
  if [[ "$effect" == "none" && "$bright" == "1.00" ]]; then
    # Ничего не активно — модуль прячется (пустой text).
    printf '{"text":"","tooltip":"","class":"off"}\n'
  elif [[ "$effect" == "none" ]]; then
    printf '{"text":"🔅 %s%%","tooltip":"Яркость %s%%","class":"dim"}\n' "$pct" "$pct"
  elif [[ "$bright" == "1.00" ]]; then
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$emoji" "${LABEL[$effect]}" "$effect"
  else
    printf '{"text":"%s %s%%","tooltip":"%s · яркость %s%%","class":"%s"}\n' \
      "$emoji" "$pct" "${LABEL[$effect]}" "$pct" "$effect"
  fi
}

# Список «<эмодзи> <подпись>|<значение>» в порядке EFFECTS — единый источник
# правды для rofi-пикера (rofi-shader.sh читает именно это).
cmd_menu() {
  local e
  for e in "${EFFECTS[@]}"; do
    printf '%s %s|%s\n' "${EMOJI[$e]}" "${LABEL[$e]}" "$e"
  done
}

case "${1:-}" in
  effect)  shift; cmd_effect "$@" ;;
  bright)  shift; cmd_bright "$@" ;;
  restore) cmd_restore ;;
  status)  cmd_status ;;
  menu)    cmd_menu ;;
  *) notify_error "Usage: screen-shader.sh effect|bright|restore|status|menu ..."; exit 1 ;;
esac
