#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
toggle-theme.sh — тумблер light/dark темы (бинд SUPER+A)

Использование:
  toggle-theme.sh           переключить тему на противоположную
  toggle-theme.sh --sync    только привести систему к сохранённому выбору
                            (exec на каждом reload Hyprland)
  toggle-theme.sh --help    эта справка

Тема живёт в рантайме, не в Nix: скрипт флипает color-scheme + gtk-theme в
dconf и подменяет симлинк темы rofi. Выбор хранится durable в
~/.local/state/huix/theme — dconf load на nixos-rebuild сбрасывает тему,
--sync возвращает её обратно. Имена тем/ключей приходят из env (Nix-обёртка).
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
  ROFI_ACTIVE_THEME

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

# Применить тему по имени состояния (dark|light): dconf + символлинк темы rofi и
# фиксация выбора в state-файле. Без уведомления — это "тихое" применение.
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

# Тоггл флипает относительно сохранённого выбора; повторно dconf не опрашиваем.
# detect_theme_state нужен только на первом запуске, когда state-файла ещё нет
# (unset → как и раньше через sync=light: net-результат dark).
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
