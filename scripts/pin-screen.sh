#!/usr/bin/env bash

# Pins a selected region above all windows: a grim screenshot into swayimg, class
# desktop-pin, with float rules in hyprland.lua
# Geometry comes from swayimg's own --position/--size: on Hyprland they become a window
# rule applied when the window maps, so nothing has to move the window afterwards

GEOM=$(slurp -b ffffff66 -w 1 -f "%x %y %w %h")
[ -z "$GEOM" ] && exit 0

read -r X Y W H <<<"$GEOM"

# That rule moves a window relative to its own monitor, while slurp reports global
# coordinates: subtract the origin of the monitor the window will map on, which is the
# focused one, as hyprland picks the focused monitor for a new window
FOCUS=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | "\(.x) \(.y)"')
read -r MONX MONY <<<"${FOCUS:-0 0}"

FILE="/tmp/pin_$(date +%s).png"
grim -g "$X,$Y ${W}x${H}" "$FILE"

(
  # LC_NUMERIC=C: otherwise a comma locale breaks coordinate parsing
  # set_default_scale("fill"): the image fills the window without borders — with a
  # fractional monitor scale rounding otherwise leaves a thin empty margin at the edge
  LC_NUMERIC=C swayimg \
    --appid="desktop-pin" \
    --position="$((X - MONX)),$((Y - MONY))" \
    --size="$W,$H" \
    -e 'swayimg.viewer.default_scale = "fill"' \
    "$FILE"
  rm -f "$FILE"
)
