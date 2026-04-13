#!/usr/bin/env bash

set -euo pipefail

GTK_THEME_KEY="/org/gnome/desktop/interface/gtk-theme"
COLOR_SCHEME_KEY="/org/gnome/desktop/interface/color-scheme"
ROFI_THEMES_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi/themes"
ROFI_LIGHT_THEME="$ROFI_THEMES_DIR/light.rasi"
ROFI_DARK_THEME="$ROFI_THEMES_DIR/dark.rasi"
ROFI_ACTIVE_THEME="$ROFI_THEMES_DIR/active.rasi"

LIGHT_THEME="Gruvbox-Light"
DARK_THEME="Gruvbox-Dark"
LIGHT_SCHEME="prefer-light"
DARK_SCHEME="prefer-dark"

current_theme=$(dconf read "$GTK_THEME_KEY" 2>/dev/null || true)
current_scheme=$(dconf read "$COLOR_SCHEME_KEY" 2>/dev/null || true)

set_rofi_theme() {
  local theme_path="$1"

  mkdir -p "$ROFI_THEMES_DIR"
  ln -sfn "$theme_path" "$ROFI_ACTIVE_THEME"
}

set_theme() {
  local theme="$1"
  local scheme="$2"
  local rofi_theme="$3"
  local message="$4"

  dconf write "$GTK_THEME_KEY" "'${theme}'"
  dconf write "$COLOR_SCHEME_KEY" "'${scheme}'"
  set_rofi_theme "$rofi_theme"
  notify-send -u low "$message"
}

if [[ "${1:-}" == "--sync" ]]; then
  if [[ "${current_theme,,}" == *"dark"* ]] || [[ "$current_scheme" == "'${DARK_SCHEME}'" ]]; then
    set_rofi_theme "$ROFI_DARK_THEME"
  else
    set_rofi_theme "$ROFI_LIGHT_THEME"
  fi
  exit 0
fi

if [[ "${current_theme,,}" == *"dark"* ]] || [[ "$current_scheme" == "'${DARK_SCHEME}'" ]]; then
  set_theme "$LIGHT_THEME" "$LIGHT_SCHEME" "$ROFI_LIGHT_THEME" "Light theme set 🌕"
elif [[ "${current_theme,,}" == *"light"* ]] || [[ "$current_scheme" == "'${LIGHT_SCHEME}'" ]] || [[ -z "$current_theme" ]]; then
  set_theme "$DARK_THEME" "$DARK_SCHEME" "$ROFI_DARK_THEME" "Dark theme set 🌑"
else
  notify-send -u critical "Cannot determine theme state ヽ(ﾟДﾟ)ﾉ"
  exit 1
fi
