#!/usr/bin/env bash

# hyprpicker screencopies the already-shaded output and Hyprland shades its frozen
# overlay a second time, so the picture doubles the effect and the hex comes out
# tinted. Drop the shader for the pick (durable state untouched) and let the manager
# put it back — the trap covers Escape and a kill too
hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
trap 'screen-shader restore' EXIT

color=$(hyprpicker -a -r)
if [[ -n "$color" ]]; then
  r=$((16#${color:1:2}))
  g=$((16#${color:3:2}))
  b=$((16#${color:5:2}))
  magick -size 64x64 xc:"$color" /tmp/c.png
  notify-send -i /tmp/c.png "Color Copied" "HEX: $color\nRGB: $r, $g, $b"
fi
