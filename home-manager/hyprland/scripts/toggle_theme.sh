#!/usr/bin/env bash

set -euo pipefail

GTK_THEME_KEY="/org/gnome/desktop/interface/gtk-theme"
COLOR_SCHEME_KEY="/org/gnome/desktop/interface/color-scheme"

LIGHT_THEME="Gruvbox-Light"
DARK_THEME="Gruvbox-Dark"
LIGHT_SCHEME="prefer-light"
DARK_SCHEME="prefer-dark"

current_theme=$(dconf read "$GTK_THEME_KEY" 2>/dev/null || true)
current_scheme=$(dconf read "$COLOR_SCHEME_KEY" 2>/dev/null || true)

set_theme() {
  local theme="$1"
  local scheme="$2"
  local message="$3"

  dconf write "$GTK_THEME_KEY" "'${theme}'"
  dconf write "$COLOR_SCHEME_KEY" "'${scheme}'"
  notify-send -u low "$message"
}

if [[ "${current_theme,,}" == *"dark"* ]] || [[ "$current_scheme" == "'${DARK_SCHEME}'" ]]; then
  set_theme "$LIGHT_THEME" "$LIGHT_SCHEME" "Light theme set 🌕"
elif [[ "${current_theme,,}" == *"light"* ]] || [[ "$current_scheme" == "'${LIGHT_SCHEME}'" ]] || [[ -z "$current_theme" ]]; then
  set_theme "$DARK_THEME" "$DARK_SCHEME" "Dark theme set 🌑"
else
  notify-send -u critical "Cannot determine theme state ヽ(ﾟДﾟ)ﾉ"
  exit 1
fi
