#!/usr/bin/env bash

# Закрепляет выделенную область экрана поверх окон: grim-скриншот открывается
# swayimg-окном класса desktop-pin ровно на месте выделения (float-правила для
# класса — в hyprland.conf).

GEOM=$(slurp -b ffffff66 -w 1 -f "%x %y %w %h")
[ -z "$GEOM" ] && exit 0

read -r X Y W H <<<"$GEOM"

FILE="/tmp/pin_$(date +%s).png"
grim -g "$X,$Y ${W}x${H}" "$FILE"

(
  # LC_NUMERIC=C: иначе локаль с запятой ломает разбор координат
  LC_NUMERIC=C swayimg \
    --class="desktop-pin" \
    --position="$X,$Y" \
    --size="$W,$H" \
    "$FILE"
  rm -f "$FILE"
)
