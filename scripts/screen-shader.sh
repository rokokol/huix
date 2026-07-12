#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
screen-shader.sh — менеджер полноэкранных шейдеров и софт-яркости Hyprland

Команды:
  effect push <name>     ДОБАВИТЬ эффект в стопку (композиция поверх текущих)
  effect set <name>      ЗАМЕНИТЬ стопку одним эффектом
  effect clear           очистить стопку (все эффекты выключить)
  effect toggle <name>   есть в стопке — убрать; нет — добавить
  effect next|prev       заменить стопку следующим/предыдущим эффектом
  bright up|down         софт-яркость ±10% (кламп 10..100%)
  bright reset           яркость 100%
  bright set <0.10..1>   яркость точно
  bright get             текущая яркость в процентах (целое, для UI)
  flash [-k] <name> [sec] эффект на N секунд (деф. 1.0) и вернуть как было;
                         накладывается ПОВЕРХ текущей стопки (композиция);
                         durable state не трогается;
                         -k — no-op, если стопка непуста
  restore                перечитать state и применить заново
                         (exec на каждом reload Hyprland — слот рантаймовый)
  status                 JSON для waybar (custom/shader)
  menu                   строки "<эмодзи> <подпись>|<имя>" для rofi-пикера
                         (активные помечены номером применения: 01. 02. 03.)
  help                   эта справка

Эффекты СТАКАЮТСЯ: каждый `effect push` добавляет фильтр поверх предыдущих
(rofi-пикер шлёт именно push), и они компонуются в один шейдер, пока стопку
не очистят (`effect clear`, пункт «Обычный» в пикере или SUPER+G). У Hyprland
один слот шейдера (decoration:screen_shader), поэтому все эффекты стопки плюс
яркость собираются в один генерируемый GLSL. Эффекты, сэмплящие текстуру со
смещением (crt/wave/glitch), ставятся в цепочке первыми (геометрия), цветовые
фильтры — после; несколько геометрических не складываются (последний перекрывает
предыдущие) — ограничение единственного слота. Каждый эффект в
scripts/shaders/<name>.frag описывает только функцию vec3 effect(vec3 c, vec2 uv).

Выбор (стопка эффектов + яркость) хранится durable в ~/.local/state/huix/shader —
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
EFFECTS=(none grayscale sepia invert warm cool vignette sharpen crt matrix posterize wave glitch jpeg)

# Анимированные эффекты (используют uniform time). Им нужен выключенный
# damage tracking, иначе Hyprland не перерисовывает кадр.
ANIMATED=(wave glitch matrix)

# Статичные эффекты, которые сэмплят текстуру со СМЕЩЕНИЕМ (кривизна, искажение).
# При точном damage tracking (2) они читают непереисованные соседние области и
# "ломаются" на быстрых изменениях экрана. Им нужна перерисовка ВСЕГО монитора
# при любом изменении (damage_tracking 1), но в простое можно спать — анимации нет.
OFFSET=(crt jpeg sharpen)

# Эффекты, которые двигают пиксели ГЕОМЕТРИЧЕСКИ (кривизна/искажение). Для них
# включаем ПРОГРАММНЫЙ курсор, чтобы он проходил через шейдер вместе с экраном:
# аппаратный курсор рисуется оверлеем мимо шейдера и не совпадает с искажённым
# контентом (из-за чего клики у краёв уезжают). Для остальных — аппаратный (быстрее).
WARP=(crt wave glitch)

# Эмодзи и подписи для индикатора в waybar (status) — один источник правды.
declare -A EMOJI=(
  [none]="🌈" [grayscale]="⚫" [sepia]="🟤" [invert]="🔄" [warm]="🌅"
  [cool]="❄️" [vignette]="🎯" [sharpen]="🔪" [crt]="📺" [matrix]="🟢"
  [posterize]="🎨" [wave]="🌊" [glitch]="📡" [jpeg]="💾"
)
declare -A LABEL=(
  [none]="Обычный" [grayscale]="Чёрно-белый" [sepia]="Сепия" [invert]="Негатив"
  [warm]="Тёплый (ночь)" [cool]="Холодный" [vignette]="Виньетка" [sharpen]="Резкость"
  [crt]="Кинескоп" [matrix]="Матрица" [posterize]="Постеризация" [wave]="Волна"
  [glitch]="Глитч" [jpeg]="JPEG"
)

mkdir -p "$STATE_DIR"

# Стопка активных эффектов (по порядку добавления). Пустая = ничего не наложено.
stack=()
bright="1.00"
# Hyprland НЕ перекомпилирует шейдер, если задать тот же путь. Поэтому пишем
# в чередующиеся файлы (active-0/active-1) — путь всегда меняется и шейдер
# гарантированно перечитывается (иначе смена яркости при активной стопке
# не применяется).
slot=0

load_state() {
  stack=()
  if [[ -f "$STATE" ]]; then
    # shellcheck disable=SC1090
    source "$STATE"
  fi
  # Миграция со старого формата (одиночный effect=<name>).
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

# Индекс эффекта в EFFECTS (или -1).
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

# 1-based позиция эффекта в стопке (порядок применения) — печатает номер и
# возвращает 0, если эффект в стопке; иначе возвращает 1 и ничего не печатает.
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

# Эффект сам сэмплит текстуру (геометрия/искажение) — такой в цепочке идёт первым.
samples_texture() {
  grep -q 'texture(' "$SHADER_DIR/$1.frag"
}

# Режим отрисовки по списку эффектов: берём самый требовательный.
#   animated   — есть анимация (uniform time): damage 0 (рисуем каждый кадр) + VFR off
#                (при включённом VFR Hyprland уходит в idle и анимация дёргается);
#   fullstatic — есть статичный со смещённой выборкой (кривизна): damage 1 — при
#                любом изменении перерисовываем весь монитор (иначе точный damage
#                ломает искажённую выборку), но в простое спим; VFR on;
#   default    — только попиксельные эффекты: дефолт damage 2 + VFR (частичный ok).
set_render_mode() {
  case "$1" in
  animated) hyprctl --batch "keyword debug:damage_tracking 0 ; keyword debug:vfr 0" >/dev/null ;;
  fullstatic) hyprctl --batch "keyword debug:damage_tracking 1 ; keyword debug:vfr 1" >/dev/null ;;
  *) hyprctl --batch "keyword debug:damage_tracking 2 ; keyword debug:vfr 1" >/dev/null ;;
  esac
}

render_mode_for() { # $@ = имена эффектов
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

# Программный курсор для искажающих эффектов (см. WARP) — иначе аппаратный курсор
# идёт мимо шейдера. На NVIDIA "программный курсор" = воркэраунд аппаратного, так
# что это безопасная сторона; аппаратный (false) — текущий дефолт.
set_cursor_for() { # $@ = имена эффектов
  local n
  for n in "$@"; do
    if in_list "$n" "${WARP[@]}"; then
      hyprctl keyword cursor:no_hardware_cursors true >/dev/null
      return
    fi
  done
  hyprctl keyword cursor:no_hardware_cursors false >/dev/null
}

# Переименовать все топ-уровневые определения тела эффекта (effect, hash, …)
# суффиксом $2 — для композиции нескольких тел в одном шейдере без конфликтов.
rename_defs() { # $1 = файл, $2 = суффикс
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

# Собрать полный GLSL из цепочки тел эффектов: $1 = выходной файл, далее список
# .frag-файлов. Первое тело используется как есть (функция effect), остальные
# переименовываются (effect_1, effect_2, …) и применяются по очереди к результату
# предыдущего. time в секундах от старта: если хоть один эффект его использует,
# Hyprland перерисовывает кадр непрерывно; иначе uniform вычищается компилятором.
emit_shader() {
  local out="$1"
  shift
  local bodies=("$@") b i=0
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
  } >"$out"
}

# Упорядочить стопку для цепочки: геометрические (сэмплят текстуру) — первыми,
# цветовые — после. Печатает по одному имени в строку.
ordered_stack() {
  local e
  for e in "${stack[@]}"; do samples_texture "$e" && printf '%s\n' "$e"; done
  for e in "${stack[@]}"; do samples_texture "$e" || printf '%s\n' "$e"; done
}

apply() { # $1 (опц.) = transient: не сохранять состояние в durable state
  # Полностью убираем шейдер, если ни эффектов, ни затемнения нет.
  if [[ ${#stack[@]} -eq 0 && "$bright" == "1.00" ]]; then
    set_render_mode default
    set_cursor_for none
    hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
    [[ "${1:-}" == "transient" ]] || save_state
    signal_waybar
    return
  fi

  # Список тел в порядке цепочки. Пустая стопка при bright<1 — один passthrough.
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

  # Чередуем файл, чтобы путь всегда менялся и Hyprland перечитал шейдер.
  slot=$((1 - slot))
  local active="$STATE_DIR/active-$slot.frag"
  emit_shader "$active" "${bodies[@]}"

  set_render_mode "$(render_mode_for "${stack[@]}")"
  set_cursor_for "${stack[@]}"
  hyprctl keyword decoration:screen_shader "$active" >/dev/null
  [[ "${1:-}" == "transient" ]] || save_state
  signal_waybar
}

# Проверить имя и что файл существует.
require_effect() {
  if [[ ! -f "$SHADER_DIR/$1.frag" ]]; then
    notify_error "Unknown effect: $1"
    exit 1
  fi
}

push_effect() {
  local name="$1"
  # «Обычный» = сброс всей стопки.
  if [[ "$name" == "none" ]]; then
    clear_stack
    return
  fi
  require_effect "$name"
  if in_list "$name" "${stack[@]}"; then
    notify_info "Shader" "Уже в стопке: ${LABEL[$name]} (・_・)"
    return
  fi
  stack+=("$name")
  apply
  notify_info "Shader" "Добавлен: ${LABEL[$name]} · в стопке ${#stack[@]} （-＾〇＾-）"
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
  notify_info "Shader" "Эффект: ${LABEL[$name]} （-＾〇＾-）"
}

toggle_effect() {
  local name="$1" e new=()
  # «Обычный» = сброс всей стопки, а не добавление none в цепочку.
  if [[ "$name" == "none" ]]; then
    clear_stack
    return
  fi
  require_effect "$name"
  if in_list "$name" "${stack[@]}"; then
    for e in "${stack[@]}"; do [[ "$e" == "$name" ]] || new+=("$e"); done
    stack=("${new[@]}")
    apply
    notify_info "Shader" "Убран: ${LABEL[$name]} · в стопке ${#stack[@]} (・_・)"
  else
    stack+=("$name")
    apply
    notify_info "Shader" "Добавлен: ${LABEL[$name]} · в стопке ${#stack[@]} （-＾〇＾-）"
  fi
}

clear_stack() {
  stack=()
  apply
  notify_info "Shader" "Эффекты сброшены (★^O^★)"
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
  load_state
  local step="0.10"
  case "${1:-}" in
  up) bright=$(awk -v b="$bright" -v s="$step" 'BEGIN{v=b+s; if(v>1)v=1;    printf "%.2f", v}') ;;
  down) bright=$(awk -v b="$bright" -v s="$step" 'BEGIN{v=b-s; if(v<0.1)v=0.1; printf "%.2f", v}') ;;
  reset) bright="1.00" ;;
  set) bright=$(awk -v b="${2:?value required}" 'BEGIN{v=b; if(v>1)v=1; if(v<0.1)v=0.1; printf "%.2f", v}') ;;
  get)
    awk -v b="$bright" 'BEGIN{printf "%d", b*100}'
    return 0
    ;;
  *)
    notify_error "Usage: bright up|down|reset|set <0.10..1.00> | get"
    exit 1
    ;;
  esac
  apply
  # Синхронный тег: при удержании клавиши обновляется один попап, а не спамит лентой.
  command -v notify-send >/dev/null 2>&1 && notify-send -u low \
    -h string:x-canonical-private-synchronous:huix-bright \
    "Brightness" "Яркость: $(awk -v b="$bright" 'BEGIN{printf "%d", b*100}')% ☀" || true
}

# Временный эффект на N секунд, КОМПОЗИЦИЕЙ поверх текущей стопки. Durable state
# не трогается — краш посреди flash ничего не портит. Пишет в отдельный
# flash.frag, не трогая слоты active-0/1: путь восстановления после flash
# гарантированно другой, Hyprland перечитывает шейдер. Конкурентные flash
# гасятся flock; -k — выйти молча, если стопка непуста.
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

  # flash-тело первым (обычно само сэмплит текстуру — glitch/wave); из стопки в
  # цепочку берём только цветовые (не сэмплящие текстуру) — иначе они затрут
  # результат flash (честная композиция нескольких геометрий требует
  # многопроходного рендера, а у Hyprland один слот).
  local bodies=("$SHADER_DIR/$name.frag") e
  for e in "${stack[@]}"; do
    samples_texture "$e" || bodies+=("$SHADER_DIR/$e.frag")
  done
  local file="$STATE_DIR/flash.frag"
  emit_shader "$file" "${bodies[@]}"

  # Режим отрисовки/курсор — по всей паре (flash + стопка).
  set_render_mode "$(render_mode_for "$name" "${stack[@]}")"
  set_cursor_for "$name" "${stack[@]}"

  hyprctl keyword decoration:screen_shader "$file" >/dev/null
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

# JSON для waybar (custom/shader): эмодзи всех эффектов стопки + процент яркости.
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
    # Ничего не активно — модуль прячется (пустой text).
    printf '{"text":"","tooltip":"","class":"off"}\n'
  elif [[ ${#stack[@]} -eq 0 ]]; then
    printf '{"text":"🔅 %s%%","tooltip":"Яркость %s%%","class":"dim"}\n' "$pct" "$pct"
  elif [[ "$bright" == "1.00" ]]; then
    printf '{"text":"%s","tooltip":"%s","class":"%s"}\n' "$emoji" "$labels" "$class"
  else
    printf '{"text":"%s %s%%","tooltip":"%s · яркость %s%%","class":"%s"}\n' \
      "$emoji" "$pct" "$labels" "$pct" "$class"
  fi
}

# Список "<эмодзи> <подпись>|<значение>" в порядке EFFECTS — единый источник
# правды для rofi-пикера (rofi-shader.sh читает именно это). Активные в стопке
# помечаются номером применения в формате "01. " (порядок стопки = порядок, в
# котором эффекты добавляли), чтобы видеть накопленную композицию и её порядок.
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
status) cmd_status ;;
menu) cmd_menu ;;
help | -h | --help) usage ;;
*)
  usage >&2
  notify_error "Usage: screen-shader.sh effect|bright|restore|status|menu|help"
  exit 1
  ;;
esac
