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
DEFAULT_THEME="$LIGHT_THEME"
DEFAULT_SCHEME="$LIGHT_SCHEME"

read_current_theme() {
  dconf read "$GTK_THEME_KEY" 2>/dev/null || true
}

read_current_scheme() {
  dconf read "$COLOR_SCHEME_KEY" 2>/dev/null || true
}

current_theme=$(read_current_theme)
current_scheme=$(read_current_scheme)

set_rofi_theme() {
  local theme_path="$1"

  mkdir -p "$ROFI_THEMES_DIR"
  ln -sfn "$theme_path" "$ROFI_ACTIVE_THEME"
}

detect_theme_state() {
  if [[ "${current_theme,,}" == *"dark"* ]] || [[ "$current_scheme" == "'${DARK_SCHEME}'" ]]; then
    echo "dark"
  elif [[ "${current_theme,,}" == *"light"* ]] || [[ "$current_scheme" == "'${LIGHT_SCHEME}'" ]]; then
    echo "light"
  elif [[ -z "$current_theme" ]] && [[ -z "$current_scheme" ]]; then
    echo "unset"
  else
    echo "unknown"
  fi
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

sync_theme_state() {
  case "$(detect_theme_state)" in
    dark)
      dconf write "$GTK_THEME_KEY" "'${DARK_THEME}'"
      dconf write "$COLOR_SCHEME_KEY" "'${DARK_SCHEME}'"
      set_rofi_theme "$ROFI_DARK_THEME"
      ;;
    light)
      dconf write "$GTK_THEME_KEY" "'${LIGHT_THEME}'"
      dconf write "$COLOR_SCHEME_KEY" "'${LIGHT_SCHEME}'"
      set_rofi_theme "$ROFI_LIGHT_THEME"
      ;;
    unset)
      # Keep startup state aligned with the declarative Home Manager default theme.
      dconf write "$GTK_THEME_KEY" "'${DEFAULT_THEME}'"
      dconf write "$COLOR_SCHEME_KEY" "'${DEFAULT_SCHEME}'"
      set_rofi_theme "$ROFI_LIGHT_THEME"
      ;;
    *)
      notify-send -u critical "Cannot sync theme state ヽ(ﾟДﾟ)ﾉ"
      exit 1
      ;;
  esac
}

if [[ "${1:-}" == "--sync" ]]; then
  sync_theme_state
  exit 0
fi

sync_theme_state
current_theme=$(read_current_theme)
current_scheme=$(read_current_scheme)

if [[ "$(detect_theme_state)" == "dark" ]]; then
  set_theme "$LIGHT_THEME" "$LIGHT_SCHEME" "$ROFI_LIGHT_THEME" "Light theme set 🌕"
elif [[ "$(detect_theme_state)" == "light" ]]; then
  set_theme "$DARK_THEME" "$DARK_SCHEME" "$ROFI_DARK_THEME" "Dark theme set 🌑"
else
  notify-send -u critical "Cannot determine theme state ヽ(ﾟДﾟ)ﾉ"
  exit 1
fi
