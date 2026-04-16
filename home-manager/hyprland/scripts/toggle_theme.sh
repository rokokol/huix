#!/usr/bin/env bash

set -euo pipefail

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Theme switch error" "$1" && return
  fi

  printf '%s\n' "$1" >&2
}

require_env() {
  local missing=()
  local name

  for name in "$@"; do
    if [[ -z "${!name:-}" ]]; then
      missing+=("$name")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    notify_error "Missing environment variables: ${missing[*]}"
    exit 1
  fi
}

require_env \
  GTK_THEME_KEY \
  COLOR_SCHEME_KEY \
  LIGHT_THEME \
  DARK_THEME \
  LIGHT_SCHEME \
  DARK_SCHEME \
  DEFAULT_THEME \
  DEFAULT_SCHEME \
  ROFI_THEMES_DIR \
  ROFI_LIGHT_THEME \
  ROFI_DARK_THEME \
  ROFI_ACTIVE_THEME

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
      notify_error "Cannot sync theme state ヽ(ﾟДﾟ)ﾉ"
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
  notify_error "Cannot determine theme state ヽ(ﾟДﾟ)ﾉ"
  exit 1
fi
