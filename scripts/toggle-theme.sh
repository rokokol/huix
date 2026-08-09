#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
toggle-theme.sh — light/dark theme toggle (bind SUPER+A)

Usage:
  toggle-theme.sh           switch the theme to the opposite one
  toggle-theme.sh --sync    only bring the system to the saved choice
                            (exec on every Hyprland reload)
  toggle-theme.sh --help    this help

The theme lives at runtime, not in Nix: the script flips color-scheme + gtk-theme
in dconf, swaps the rofi theme symlink and the libadwaita ~/.config/gtk-4.0/gtk.css
(so libadwaita apps follow too). The choice is stored durably in
~/.local/state/huix/theme — dconf load on nixos-rebuild resets the theme, --sync
brings it back. Theme/key names come from the env (Nix wrapper)
EOF
}

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Theme switch error (╯°□°）╯︵ ┻━┻" "$1" && return
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

  if ((${#missing[@]} > 0)); then
    notify_error "${missing[*]}"
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
  ROFI_THEMES_DIR \
  ROFI_LIGHT_THEME \
  ROFI_DARK_THEME \
  ROFI_ACTIVE_THEME \
  GTK4_LIGHT_CSS \
  GTK4_DARK_CSS

STATE_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/huix/theme"

save_state() {
  mkdir -p "$(dirname "$STATE_FILE")"
  printf '%s\n' "$1" >"$STATE_FILE"
}

read_state() {
  [[ -r "$STATE_FILE" ]] && cat "$STATE_FILE" || true
}

read_current_theme() {
  dconf read "$GTK_THEME_KEY" 2>/dev/null || true
}

read_current_scheme() {
  dconf read "$COLOR_SCHEME_KEY" 2>/dev/null || true
}

set_rofi_theme() {
  local theme_path="$1"

  mkdir -p "$ROFI_THEMES_DIR"
  ln -sfn "$theme_path" "$ROFI_ACTIVE_THEME"
}

# libadwaita ignores gtk-theme-name; it only reads ~/.config/gtk-4.0/gtk.css.
# Colours alone recolour it — assets are for the full sheet we deliberately skip
set_libadwaita_css() {
  local src="$1"
  local dst="${XDG_CONFIG_HOME:-$HOME/.config}/gtk-4.0"

  mkdir -p "$dst"
  ln -sfn "$src" "$dst/gtk.css"
  rm -f "$dst/assets"

  # to make swayosd notice the changes. Best-effort on purpose: aborting here would
  # leave the state file disagreeing with the dconf we have already written
  systemctl --user restart swayosd || notify_error "swayosd restart failed"
}

detect_theme_state() {
  local current_theme current_scheme
  current_theme=$(read_current_theme)
  current_scheme=$(read_current_scheme)
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

# Apply a theme by state name (dark|light): dconf + the rofi theme symlink and
# committing the choice to the state file. No notification — this is a "silent" apply
apply_state() {
  case "$1" in
  dark)
    dconf write "$GTK_THEME_KEY" "'${DARK_THEME}'"
    dconf write "$COLOR_SCHEME_KEY" "'${DARK_SCHEME}'"
    set_rofi_theme "$ROFI_DARK_THEME"
    set_libadwaita_css "$GTK4_DARK_CSS"
    save_state "dark"
    ;;
  light)
    dconf write "$GTK_THEME_KEY" "'${LIGHT_THEME}'"
    dconf write "$COLOR_SCHEME_KEY" "'${LIGHT_SCHEME}'"
    set_rofi_theme "$ROFI_LIGHT_THEME"
    set_libadwaita_css "$GTK4_LIGHT_CSS"
    save_state "light"
    ;;
  *)
    return 1
    ;;
  esac
}

set_theme() {
  local state="$1"
  local message="$2"

  apply_state "$state"
  notify-send -u low "$message"
}

# Bring the system to the saved choice. The source of truth is the state file; if
# it doesn't exist yet (first run), take the current dconf state and commit it
sync_theme_state() {
  local want
  want=$(read_state)
  [[ -n "$want" ]] || want=$(detect_theme_state)

  case "$want" in
  dark) apply_state dark ;;
  light) apply_state light ;;
  unset) apply_state light ;;
  *)
    notify_error "Cannot sync theme state ヽ(ﾟДﾟ)ﾉ"
    exit 1
    ;;
  esac
}

case "${1:-}" in
--sync)
  sync_theme_state
  exit 0
  ;;
help | -h | --help)
  usage
  exit 0
  ;;
esac

# The toggle flips relative to the saved choice; we don't re-query dconf
# detect_theme_state is needed only on the first run, when the state file doesn't
# exist yet (unset → as before via sync=light: net result dark)
case "$(read_state)" in
dark) current="dark" ;;
light) current="light" ;;
*) current="$(detect_theme_state)" ;;
esac

case "$current" in
dark) set_theme light "Light theme set 🌕" ;;
light | unset) set_theme dark "Dark theme set 🌑" ;;
*)
  notify_error "Cannot determine theme state ヽ(ﾟДﾟ)ﾉ"
  exit 1
  ;;
esac
