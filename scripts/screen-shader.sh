#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
screen-shader.sh — менеджер полноэкранных шейдеров и софт-яркости Hyprland

Команды:
  effect set <name>      поставить эффект (имена — см. menu)
  effect off-or <name>   есть эффект — выключить; нет — включить <name>
  effect next|prev       листать эффекты по кругу
  bright up|down         софт-яркость ±10% (кламп 10..100%)
  bright reset           яркость 100%
  bright set <0.10..1>   яркость точно
  flash [-k] <name> [sec] эффект на N секунд (деф. 1.0) и вернуть как было;
                         durable state не трогается; -k — no-op, если уже
                         активен какой-то эффект (не перебивать его)
  restore                перечитать state и применить заново
                         (exec на каждом reload Hyprland — слот рантаймовый)
  status                 JSON для waybar (custom/shader)
  menu                   строки "<эмодзи> <подпись>|<имя>" для rofi-пикера
  help                   эта справка

У Hyprland один слот шейдера (decoration:screen_shader), поэтому эффект и
яркость нельзя включить независимо — скрипт композирует их в один
генерируемый шейдер. Каждый эффект в scripts/shaders/<name>.frag описывает
только функцию vec3 effect(vec3 c, vec2 uv).

Выбор (эффект+яркость) хранится durable в ~/.local/state/huix/shader —
переживает логаут/ребут и не виден hourly-sync; сгенерированные шейдеры
эфемерны и живут в $XDG_RUNTIME_DIR/hypr-shader.
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

# Номер SIGRTMIN+N задаёт Nix (waybar/shader.nix) через WAYBAR_SHADER_SIGNAL.
# SHADER_NO_SIGNAL гасит сигнал при restore на старте сессии: дефолтное действие
# RT-сигнала — убить процесс, а waybar мог ещё не поставить обработчик.
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

# Порядок для листания (effect next/prev). none первым — это "выключено".
EFFECTS=(none grayscale sepia invert warm cool vignette crt matrix posterize wave glitch)

# Анимированные эффекты (используют uniform time). Им нужен выключенный
# damage tracking, иначе Hyprland не перерисовывает кадр.
ANIMATED=(wave glitch matrix)

# Статичные эффекты, которые сэмплят текстуру со СМЕЩЕНИЕМ (кривизна, искажение).
# При точном damage tracking (2) они читают непереисованные соседние области и
# "ломаются" на быстрых изменениях экрана. Им нужна перерисовка ВСЕГО монитора
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
# идёт мимо шейдера. На NVIDIA "программный курсор" = воркэраунд аппаратного, так
# что это безопасная сторона; аппаратный (false) — текущий дефолт.
set_cursor_for() {
  if in_list "$1" "${WARP[@]}"; then
    hyprctl keyword cursor:no_hardware_cursors true >/dev/null
  else
    hyprctl keyword cursor:no_hardware_cursors false >/dev/null
  fi
}

apply() { # $1 (опц.) = transient: не сохранять состояние в durable state
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
    printf '#define GET_TEX(uv) texture(tex, uv).rgb\n\n'
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
  [[ "${1:-}" == "transient" ]] || save_state
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
  # Синхронный тег: при удержании клавиши обновляется один попап, а не спамит лентой.
  command -v notify-send >/dev/null 2>&1 && notify-send -u low \
    -h string:x-canonical-private-synchronous:huix-bright \
    "Brightness" "Яркость: $(awk -v b="$bright" 'BEGIN{printf "%d", b*100}')% ☀" || true
}

# Временный эффект: применить на N секунд поверх текущего состояния и вернуть
# сохранённое. Durable state не трогается — краш посреди flash ничего не
# портит, restore/rebuild видят прежний выбор. Повторный flash во время
# активного — no-op (flock), чтобы конкурентные вызовы не дрались за слот.
# -k (keep): выйти молча, если сейчас активен какой-то эффект.
#
# Flash пишет шейдер в отдельный файл (flash.frag), не трогая слоты
# active-0/active-1. Когда flash завершается и восстанавливает основной
# шейдер через load_state + apply, путь гарантированно отличается от
# flash.frag — Hyprland перечитывает шейдер.
cmd_flash() {
  SHADER_NO_SIGNAL=1
  local keep=""
  if [[ "${1:-}" == "-k" ]]; then
    keep=1
    shift
  fi
  exec 9>"$STATE_DIR/.flash.lock"
  flock -n 9 || exit 0
  local dur="${2:-1.0}"
  load_state
  [[ -n "$keep" && "$effect" != "none" ]] && exit 0
  local flash_effect="${1:?effect name required}"
  local flash_body="$SHADER_DIR/$flash_effect.frag"
  if [[ ! -f "$flash_body" ]]; then
    notify_error "Shader not found: $flash_body"
    exit 1
  fi
  # Пишем flash-шейдер в отдельный файл, не трогая active-*/slot.
  local flash_file="$STATE_DIR/flash.frag"
  {
    printf '#version 300 es\n'
    printf 'precision highp float;\n\n'
    printf 'in vec2 v_texcoord;\n'
    printf 'uniform sampler2D tex;\n'
    printf 'uniform float time;\n'
    printf 'out vec4 fragColor;\n\n'
    printf '#define BRIGHTNESS %s\n\n' "$bright"
    if [[ "$effect" != "none" && -f "$SHADER_DIR/$effect.frag" ]]; then
      printf '#define GET_TEX(uv) texture(tex, uv).rgb\n'
      sed 's/vec3 effect/vec3 active_effect/' "$SHADER_DIR/$effect.frag"
      printf '\n#undef GET_TEX\n'
      printf '#define GET_TEX(uv) active_effect(texture(tex, uv).rgb, uv)\n'
      sed 's/vec3 effect/vec3 flash_effect/' "$flash_body"
      printf '\nvoid main() {\n'
      printf '    vec4 src = texture(tex, v_texcoord);\n'
      printf '    vec3 c = active_effect(src.rgb, v_texcoord);\n'
      printf '    c = flash_effect(c, v_texcoord);\n'
      printf '    c *= BRIGHTNESS;\n'
      printf '    fragColor = vec4(c, src.a);\n'
      printf '}\n'
    else
      printf '#define GET_TEX(uv) texture(tex, uv).rgb\n'
      cat "$flash_body"
      printf '\nvoid main() {\n'
      printf '    vec4 src = texture(tex, v_texcoord);\n'
      printf '    vec3 c = effect(src.rgb, v_texcoord);\n'
      printf '    c *= BRIGHTNESS;\n'
      printf '    fragColor = vec4(c, src.a);\n'
      printf '}\n'
    fi
  } >"$flash_file"
  set_render_mode "$(render_mode_for "$flash_effect")"
  set_cursor_for "$flash_effect"
  hyprctl keyword decoration:screen_shader "$flash_file" >/dev/null
  sleep "$dur"
  load_state
  apply
}

cmd_restore() {
  # Не сигналим waybar на старте сессии (см. signal_waybar); скрипт тут же
  # завершается, так что глобальная установка флага безопасна.
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

# Список "<эмодзи> <подпись>|<значение>" в порядке EFFECTS — единый источник
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
  flash)   shift; cmd_flash "$@" ;;
  restore) cmd_restore ;;
  status)  cmd_status ;;
  menu)    cmd_menu ;;
  help | -h | --help) usage ;;
  *)
    usage >&2
    notify_error "Usage: screen-shader.sh effect|bright|restore|status|menu|help"
    exit 1
    ;;
esac
