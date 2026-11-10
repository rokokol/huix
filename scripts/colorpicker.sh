#!/usr/bin/env bash

# hyprpicker screencopies the already-shaded output and Hyprland shades its frozen
# overlay a second time, so the picture doubles the effect and the hex comes out
# tinted. Drop the shader for the pick (durable state untouched) and let the manager
# put it back — the trap covers Escape and a kill too

usage() {
  cat <<'EOF'
colorpicker.sh — pick a colour off the screen and copy it as a hex value

  colorpicker.sh          pick a colour, copy it, and notify with its HEX and RGB
  colorpicker.sh help     this text

The colour goes to the clipboard as a hex value. The screen shader is off for the pick,
because it would tint the frozen overlay, and comes back on exit
Exit 0 when a colour was picked, 1 when the pick was cancelled
EOF
}

case "${1:-}" in
  -h | --help | help)
    usage
    exit 0
    ;;
esac

hyprctl eval 'hl.config({ decoration = { screen_shader = "" } })' >/dev/null
trap 'screen-shader restore' EXIT

color=$(hyprpicker -a -r)
if [[ -n "$color" ]]; then
  r=$((16#${color:1:2}))
  g=$((16#${color:3:2}))
  b=$((16#${color:5:2}))
  magick -size 64x64 xc:"$color" /tmp/c.png
  notify-send -i /tmp/c.png "Color Copied" "HEX: $color\nRGB: $r, $g, $b"
fi
