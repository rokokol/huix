#!/usr/bin/env bash

set -euo pipefail

# Аниматор DDLC-стикеров для hyprlock (image-виджет, см. hyprlock.nix).
#
# Каждую секунду hyprlock дёргает этот скрипт как reload_cmd и ждёт путь к
# картинке. reload_cmd исполняется СИНХРОННО в главном цикле hyprlock — любая
# задержка фризит локскрин, поэтому скрипт мгновенно отдаёт УЖЕ готовый кадр,
# а следующий рисует фоновым процессом (двойной буфер через atomic mv:
# путь не меняется, hyprlock перечитывает кадр по mtime).
#
# Поведение стикеров: каждый бродит по нижней полосе экрана — идёт к случайной
# цели со своей скоростью, стоит случайную паузу, идёт дальше. Независимо от
# ходьбы каждый прыгает: интервал между прыжками — гауссовский (Box-Muller),
# прыжок длится один тик.

HUIX="${HUIX:-$(cd -- "$(dirname -- "$0")/.." && pwd)}"
ASSETS="$HUIX/assets/ddlc-stickers"

CANVAS_W=1920
CANVAS_H=340
SPRITE_H=170 # высота стикера после скейла
X_MARGIN=20  # отступ блуждания от краёв канвы

SPEED_MIN=30 SPEED_MAX=110 # px за тик, своя на каждый переход
PAUSE_MIN=2 PAUSE_MAX=8    # стоянка на цели, сек

JUMP_MEAN=25 JUMP_SD=10      # гауссовский интервал прыжков, сек
JUMP_H_MIN=50 JUMP_H_MAX=130 # высота прыжка, px

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc/stickers"
CACHE="$STATE_DIR/cache"
OUT="$STATE_DIR/frame.png"

mkdir -p "$CACHE"

gauss_delay() {
  awk -v m="$JUMP_MEAN" -v s="$JUMP_SD" -v seed="$(((RANDOM << 15) + RANDOM))" '
    BEGIN {
      srand(seed)
      g = sqrt(-2 * log(1 - rand())) * cos(6.2831853 * rand())
      d = m + s * g
      if (d < 4) d = 4
      printf "%d", d
    }'
}

compose_next() {
  local now f name png x target speed pause_until next_jump yoff y st
  now=$(date +%s)

  local args=(-size "${CANVAS_W}x${CANVAS_H}" xc:none)

  for f in "$ASSETS"/*.webp; do
    name=$(basename "$f" .webp)
    png="$CACHE/$name.png"
    # пре-скейл один раз за сессию — композить каждый тик оригиналы дорого
    [[ -f "$png" ]] || magick "$f" -resize "x$SPRITE_H" "$png"

    st="$STATE_DIR/$name.state"
    if [[ -f "$st" ]]; then
      read -r x target speed pause_until next_jump <"$st"
    else
      x=$((X_MARGIN + RANDOM % (CANVAS_W - 2 * X_MARGIN - 150)))
      target=$x
      speed=0
      pause_until=$((now + RANDOM % (PAUSE_MAX + 1)))
      next_jump=$((now + 4 + RANDOM % (2 * JUMP_MEAN)))
    fi

    # ходьба: пауза -> новая цель+скорость -> шаги до цели -> пауза
    if ((now >= pause_until)); then
      if ((x == target)); then
        target=$((X_MARGIN + RANDOM % (CANVAS_W - 2 * X_MARGIN - 150)))
        speed=$((SPEED_MIN + RANDOM % (SPEED_MAX - SPEED_MIN + 1)))
      fi
      if ((x < target)); then
        x=$((x + speed))
        ((x >= target)) && { x=$target; pause_until=$((now + PAUSE_MIN + RANDOM % (PAUSE_MAX - PAUSE_MIN + 1))); }
      elif ((x > target)); then
        x=$((x - speed))
        ((x <= target)) && { x=$target; pause_until=$((now + PAUSE_MIN + RANDOM % (PAUSE_MAX - PAUSE_MIN + 1))); }
      fi
    fi

    # прыжок: один тик в воздухе, следующий момент — по Гауссу
    yoff=0
    if ((now >= next_jump)); then
      yoff=$((JUMP_H_MIN + RANDOM % (JUMP_H_MAX - JUMP_H_MIN + 1)))
      next_jump=$((now + $(gauss_delay)))
    fi

    printf '%s %s %s %s %s\n' "$x" "$target" "$speed" "$pause_until" "$next_jump" >"$st"

    y=$((CANVAS_H - SPRITE_H - yoff))
    args+=("(" "$png" ")" -geometry "+${x}+${y}" -composite)
  done

  magick "${args[@]}" "png32:$OUT.tmp"
  mv "$OUT.tmp" "$OUT"
}

# Первый вызов: настоящий кадр (пре-скейл стикеров + композиция) занимает
# ~секунду и заморозил бы главный цикл hyprlock, поэтому синхронно отдаём
# пустую канву (~40ms), а первый настоящий кадр рисуем уже фоном.
[[ -f "$OUT" ]] || magick -size "${CANVAS_W}x${CANVAS_H}" xc:none "png32:$OUT"

# Фоновой композер следующего кадра; flock защищает от наслоения, если
# предыдущий ещё не дорисовал. stdout закрыт — иначе hyprlock ждёт EOF.
(flock -n 9 && compose_next) 9>"$STATE_DIR/.lock" >/dev/null 2>&1 &

printf '%s' "$OUT"
