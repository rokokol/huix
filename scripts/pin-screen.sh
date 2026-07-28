#!/usr/bin/env bash

# Закрепляет выделенную область экрана поверх окон: grim-скриншот открывается
# swayimg-окном класса desktop-pin ровно на месте выделения (float-правила для
# класса — в hyprland.conf).
#
# Позицию и размер окна задаём через hyprctl, а не флагами swayimg: на Hyprland
# с дробным масштабом swayimg 5.4 игнорирует --position/--size и открывает окно
# по центру дефолтного размера (картинка не на месте выделения + пустое поле).

GEOM=$(slurp -b ffffff66 -w 1 -f "%x %y %w %h")
[ -z "$GEOM" ] && exit 0

read -r X Y W H <<<"$GEOM"

FILE="/tmp/pin_$(date +%s).png"
grim -g "$X,$Y ${W}x${H}" "$FILE"

(
  # LC_NUMERIC=C: иначе локаль с запятой ломает разбор координат
  # set_default_scale("fill"): картинка заполняет окно без рамок — при дробном
  # масштабе монитора округление иначе оставляет тонкое пустое поле по краю.
  LC_NUMERIC=C swayimg \
    --appid="desktop-pin" \
    --size="$W,$H" \
    -e 'swayimg.viewer.set_default_scale("fill")' \
    "$FILE" &
  SWPID=$!

  # Ждём, пока окно смапится, и ставим точную геометрию (координаты slurp и
  # movewindowpixel/resizewindowpixel — в логических пикселях, совпадают).
  for _ in $(seq 1 100); do
    ADDR=$(hyprctl clients -j | jq -r ".[] | select(.pid==$SWPID) | .address")
    [ -n "$ADDR" ] && break
    sleep 0.02
  done
  if [ -n "$ADDR" ]; then
    hyprctl --batch \
      "dispatch resizewindowpixel exact $W $H,address:$ADDR; dispatch movewindowpixel exact $X $Y,address:$ADDR"
  fi

  wait "$SWPID"
  rm -f "$FILE"
)
