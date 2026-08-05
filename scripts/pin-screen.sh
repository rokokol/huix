#!/usr/bin/env bash

# Pins a selected screen region above windows: a grim screenshot opens in a
# swayimg window of class desktop-pin exactly at the selection (float rules for the
# class are in hyprland.conf)
#
# We set the window position and size via hyprctl, not swayimg flags: on Hyprland
# with fractional scale swayimg 5.4 ignores --position/--size and opens the window
# centered at the default size (image not at the selection + empty margin)

GEOM=$(slurp -b ffffff66 -w 1 -f "%x %y %w %h")
[ -z "$GEOM" ] && exit 0

read -r X Y W H <<<"$GEOM"

FILE="/tmp/pin_$(date +%s).png"
grim -g "$X,$Y ${W}x${H}" "$FILE"

(
  # LC_NUMERIC=C: otherwise a comma locale breaks coordinate parsing
  # set_default_scale("fill"): the image fills the window without borders — with a
  # fractional monitor scale rounding otherwise leaves a thin empty margin at the edge
  LC_NUMERIC=C swayimg \
    --appid="desktop-pin" \
    --size="$W,$H" \
    -e 'swayimg.viewer.set_default_scale("fill")' \
    "$FILE" &
  SWPID=$!

  # Wait until the window maps and set the exact geometry (slurp coordinates and
  # movewindowpixel/resizewindowpixel are in logical pixels, they match)
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
