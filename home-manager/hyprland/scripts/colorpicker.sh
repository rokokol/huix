#!/usr/bin/env bash
color=$(hyprpicker -a -r)
if [[ -n "$color" ]]; then
    r=$((16#${color:1:2}))
    g=$((16#${color:3:2}))
    b=$((16#${color:5:2}))
    magick -size 64x64 xc:"$color" /tmp/c.png
    notify-send -i /tmp/c.png "Color Copied" "HEX: $color\nRGB: $r, $g, $b"
fi
