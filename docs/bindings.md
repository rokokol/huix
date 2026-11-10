---
title: Клавиши Hyprland
kind: bindings
---

# Клавиши Hyprland

<!-- generated: bindings -->

| Клавиши | Диспетчер | Аргумент | Держится |
| --- | --- | --- | --- |
| `SUPER + Q` | `exec_cmd` | `kitty` | — |
| `SUPER + C` | `window.close` | — | — |
| `SUPER + E` | `exec_cmd` | `xdg-open ~` | — |
| `SUPER + V` | `window.float` | — | — |
| `SUPER + W` | `exec_cmd` | `HUIX.menu` | — |
| `SUPER + F12` | `exec_cmd` | `loginctl lock-session` | — |
| `XF86PowerOff` | `exec_cmd` | `HUIX.scripts .. "/rofi-power.sh"` | — |
| `SUPER + Delete` | `exec_cmd` | `HUIX.scripts .. "/rofi-power.sh"` | — |
| `SUPER + P` | `window.pseudo` | — | — |
| `SUPER + T` | `layout` | `togglesplit` | — |
| `SUPER + F` | `window.fullscreen` | `{ mode = "fullscreen" }` | — |
| `SUPER + Z` | `exec_cmd` | `pidof waybar && pkill waybar \|\| waybar` | — |
| `SUPER + B` | `exec_cmd` | `HUIX.scripts .. "/rofi-clipboard.sh"` | — |
| `SUPER + N` | `exec_cmd` | `HUIX.scripts .. "/rofi-notify.sh"` | — |
| `SUPER + SHIFT + N` | `exec_cmd` | `HUIX.scripts .. "/notify-center.sh dnd toggle"` | — |
| `SUPER + A` | `exec_cmd` | `HUIX.scripts .. "/toggle-theme.sh"` | — |
| `SUPER + Y` | `exec_cmd` | `rofi-wooordhunt` | — |
| `SUPER + SHIFT + G` | `exec_cmd` | `rofi-shader` | — |
| `SUPER + G` | `exec_cmd` | `screen-shader effect clear` | — |
| `SUPER + CTRL + BackSpace` | `exec_cmd` | `rofi-shader bright reset` | — |
| `SUPER + CTRL + bracketright` | `exec_cmd` | `rofi-shader bright up` | да |
| `SUPER + CTRL + bracketleft` | `exec_cmd` | `rofi-shader bright down` | да |
| `SUPER + SHIFT + B` | `exec_cmd` | `rofi -show emoji -modi "emoji:rofimoji --action copy --files '
    .. "emojis_smileys_emotion emojis_people_body emojis_animals_nature "
    .. "emojis_food_drink emojis_activities emojis_travel_places emojis_objects "
    .. "emojis_symbols emojis_flags dingbats "
    .. "miscellaneous_symbols_and_pictographs,math:rofimoji --action copy --files "
    .. "math mathematical_operators arrows geometric_shapes greek_and_coptic,"
    .. "chars:rofimoji --action copy --files currency_symbols letterlike_symbols "
    .. "latin-1_supplement general_punctuation superscripts_and_subscripts "
    .. "enclosed_alphanumerics box_drawing cjk_symbols_and_punctuation nerd_font,"
    .. 'kaomoji:rofimoji --action copy --files kaomoji"` | — |
| `SUPER + ALT + S` | `exec_cmd` | `getScreen .. " - \| GTK_THEME=Adwaita:light satty -f -"` | — |
| `SUPER + ALT + C` | `exec_cmd` | `HUIX.scripts .. "/shot-copy.sh region"` | — |
| `SUPER + ALT + A` | `exec_cmd` | `HUIX.scripts .. "/pin-screen.sh"` | — |
| `SUPER + ALT + P` | `exec_cmd` | `HUIX.scripts .. "/colorpicker.sh"` | — |
| `SUPER + ALT + T` | `exec_cmd` | `HUIX.scripts .. "/ocr.sh rus+eng"` | — |
| `SUPER + ALT + R` | `exec_cmd` | `HUIX.scripts .. "/ocr.sh rus"` | — |
| `SUPER + ALT + E` | `exec_cmd` | `HUIX.scripts .. "/ocr.sh eng"` | — |
| `SUPER + ALT + M` | `exec_cmd` | `HUIX.scripts .. "/shot-copy.sh full"` | — |
| `SUPER + ALT + mouse_down` | `exec_cmd` | `HUIX.scripts .. "/zoom.sh out"` | — |
| `SUPER + ALT + mouse_up` | `exec_cmd` | `HUIX.scripts .. "/zoom.sh in"` | — |
| `SUPER + ALT + BackSpace` | `exec_cmd` | `HUIX.scripts .. "/zoom.sh reset"` | — |
| `SUPER + H` | `focus` | `{ direction = "l" }` | — |
| `SUPER + L` | `focus` | `{ direction = "r" }` | — |
| `SUPER + K` | `focus` | `{ direction = "u" }` | — |
| `SUPER + J` | `focus` | `{ direction = "d" }` | — |
| `SUPER + left` | `focus` | `{ direction = "l" }` | — |
| `SUPER + right` | `focus` | `{ direction = "r" }` | — |
| `SUPER + up` | `focus` | `{ direction = "u" }` | — |
| `SUPER + down` | `focus` | `{ direction = "d" }` | — |
| `SUPER + SHIFT + H` | `window.move` | `{ direction = "l" }` | — |
| `SUPER + SHIFT + L` | `window.move` | `{ direction = "r" }` | — |
| `SUPER + SHIFT + K` | `window.move` | `{ direction = "u" }` | — |
| `SUPER + SHIFT + J` | `window.move` | `{ direction = "d" }` | — |
| `SUPER + SHIFT + left` | `window.move` | `{ direction = "l" }` | — |
| `SUPER + SHIFT + right` | `window.move` | `{ direction = "r" }` | — |
| `SUPER + SHIFT + up` | `window.move` | `{ direction = "u" }` | — |
| `SUPER + SHIFT + down` | `window.move` | `{ direction = "d" }` | — |
| `SUPER + CTRL + left` | `window.move` | `{ x = -80, y = 0, relative = true }` | да |
| `SUPER + CTRL + right` | `window.move` | `{ x = 80, y = 0, relative = true }` | да |
| `SUPER + CTRL + up` | `window.move` | `{ x = 0, y = -80, relative = true }` | да |
| `SUPER + CTRL + down` | `window.move` | `{ x = 0, y = 80, relative = true }` | да |
| `SUPER + CTRL + h` | `window.move` | `{ x = -80, y = 0, relative = true }` | да |
| `SUPER + CTRL + l` | `window.move` | `{ x = 80, y = 0, relative = true }` | да |
| `SUPER + CTRL + k` | `window.move` | `{ x = 0, y = -80, relative = true }` | да |
| `SUPER + CTRL + j` | `window.move` | `{ x = 0, y = 80, relative = true }` | да |
| `SUPER + 1` | `focus` | `{ workspace = "1" }` | — |
| `SUPER + 2` | `focus` | `{ workspace = "2" }` | — |
| `SUPER + 3` | `focus` | `{ workspace = "3" }` | — |
| `SUPER + 4` | `focus` | `{ workspace = "4" }` | — |
| `SUPER + 5` | `focus` | `{ workspace = "5" }` | — |
| `SUPER + 6` | `focus` | `{ workspace = "6" }` | — |
| `SUPER + 7` | `focus` | `{ workspace = "7" }` | — |
| `SUPER + 8` | `focus` | `{ workspace = "8" }` | — |
| `SUPER + 9` | `focus` | `{ workspace = "9" }` | — |
| `SUPER + SHIFT + 1` | `window.move` | `{ workspace = "1" }` | — |
| `SUPER + SHIFT + 2` | `window.move` | `{ workspace = "2" }` | — |
| `SUPER + SHIFT + 3` | `window.move` | `{ workspace = "3" }` | — |
| `SUPER + SHIFT + 4` | `window.move` | `{ workspace = "4" }` | — |
| `SUPER + SHIFT + 5` | `window.move` | `{ workspace = "5" }` | — |
| `SUPER + SHIFT + 6` | `window.move` | `{ workspace = "6" }` | — |
| `SUPER + SHIFT + 7` | `window.move` | `{ workspace = "7" }` | — |
| `SUPER + SHIFT + 8` | `window.move` | `{ workspace = "8" }` | — |
| `SUPER + SHIFT + 9` | `window.move` | `{ workspace = "9" }` | — |
| `SUPER + SHIFT + 0` | `window.move` | `{ workspace = "10" }` | — |
| `SUPER + S` | `workspace.toggle_special` | `magic` | — |
| `SUPER + SHIFT + S` | `window.move` | `{ workspace = "special:magic" }` | — |
| `SUPER + mouse_down` | `tab` | `1, focusWorkspace` | — |
| `SUPER + mouse_up` | `tab` | `-1, focusWorkspace` | — |
| `SUPER + SHIFT + mouse_down` | `tab` | `1, moveToWorkspace` | — |
| `SUPER + SHIFT + mouse_up` | `tab` | `-1, moveToWorkspace` | — |
| `SUPER + mouse:272` | `window.drag` | — | — |
| `SUPER + mouse:273` | `window.resize` | — | — |
| `XF86AudioRaiseVolume` | `exec_cmd` | `swayosd-client --output-volume raise` | да |
| `XF86AudioLowerVolume` | `exec_cmd` | `swayosd-client --output-volume lower` | да |
| `XF86AudioMute` | `exec_cmd` | `swayosd-client --output-volume mute-toggle` | — |
| `XF86AudioMicMute` | `exec_cmd` | `swayosd-client --input-volume mute-toggle` | — |
| `XF86MonBrightnessUp` | `exec_cmd` | `swayosd-client --brightness raise` | да |
| `XF86MonBrightnessDown` | `exec_cmd` | `swayosd-client --brightness lower` | да |
| `XF86AudioNext` | `exec_cmd` | `playerctl -p playerctld next` | — |
| `XF86AudioPrev` | `exec_cmd` | `playerctl -p playerctld previous` | — |
| `XF86AudioPlay` | `exec_cmd` | `playerctl -p playerctld play-pause` | — |
| `XF86AudioPause` | `exec_cmd` | `playerctl -p playerctld play-pause` | — |
| `SUPER + ALT + L` | `window.resize` | `{ x = 40, y = 0, relative = true }` | да |
| `SUPER + ALT + H` | `window.resize` | `{ x = -40, y = 0, relative = true }` | да |
| `SUPER + ALT + K` | `window.resize` | `{ x = 0, y = -40, relative = true }` | да |
| `SUPER + ALT + J` | `window.resize` | `{ x = 0, y = 40, relative = true }` | да |
| `SUPER + ALT + right` | `window.resize` | `{ x = 40, y = 0, relative = true }` | да |
| `SUPER + ALT + left` | `window.resize` | `{ x = -40, y = 0, relative = true }` | да |
| `SUPER + ALT + up` | `window.resize` | `{ x = 0, y = -40, relative = true }` | да |
| `SUPER + ALT + down` | `window.resize` | `{ x = 0, y = 40, relative = true }` | да |

<!-- /generated -->
