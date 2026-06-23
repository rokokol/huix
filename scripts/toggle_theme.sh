#!/usr/bin/env bash

set -euo pipefail

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
  ROFI_ACTIVE_THEME

# Durable-память выбранной темы. Нужна потому, что тему декларативно задаёт
# home-manager (dconf.settings + gtk.theme в theme.nix), и каждый nixos-rebuild
# при активации делает `dconf load`, затирая рантайм-выбор светлым дефолтом. Из-за
# этого dconf — ненадёжный источник правды, поэтому свой выбор (light/dark) храним
# отдельно в $XDG_STATE_HOME (переживает и ребилд, и ребут, и не лежит в git-дереве),
# а --sync на каждом reload Hyprland восстанавливает тему именно отсюда.
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

# Применить тему по имени состояния (dark|light): dconf + символлинк темы rofi и
# фиксация выбора в state-файле. Без уведомления — это «тихое» применение.
apply_state() {
  case "$1" in
  dark)
    dconf write "$GTK_THEME_KEY" "'${DARK_THEME}'"
    dconf write "$COLOR_SCHEME_KEY" "'${DARK_SCHEME}'"
    set_rofi_theme "$ROFI_DARK_THEME"
    save_state "dark"
    ;;
  light)
    dconf write "$GTK_THEME_KEY" "'${LIGHT_THEME}'"
    dconf write "$COLOR_SCHEME_KEY" "'${LIGHT_SCHEME}'"
    set_rofi_theme "$ROFI_LIGHT_THEME"
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

# Привести систему к сохранённому выбору. Источник правды — state-файл; если его
# ещё нет (первый запуск), берём текущее состояние dconf и фиксируем его.
sync_theme_state() {
  local want
  want=$(read_state)
  [[ -n "$want" ]] || want=$(detect_theme_state)

  case "$want" in
  dark) apply_state dark ;;
  light) apply_state light ;;
  # Первый старт без состояния — выравниваемся по декларативному дефолту HM (свет).
  unset) apply_state light ;;
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
  set_theme light "Light theme set 🌕"
elif [[ "$(detect_theme_state)" == "light" ]]; then
  set_theme dark "Dark theme set 🌑"
else
  notify_error "Cannot determine theme state ヽ(ﾟДﾟ)ﾉ"
  exit 1
fi
