# Sourced by the scripts that talk to Hyprland; nothing here runs on its own, so no shebang
# Needs jq and hyprctl on PATH

# The built-in panel of a laptop, or nothing on a desktop. Matched by the connector name,
# which is the only thing an internal panel and an external monitor never share
internal_monitor() {
  hyprctl monitors -j 2>/dev/null |
    jq -r 'map(select(.name | test("^(eDP|LVDS|DSI)"; "i"))) | .[0].name // empty' 2>/dev/null || true
}
