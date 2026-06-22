#!/usr/bin/env bash

# Переключает чёрно-белый (grayscale) режим монитора через screen-shader Hyprland

set -euo pipefail

notify_error() {
  if command -v notify-send >/dev/null 2>&1; then
    notify-send -u critical "Grayscale error (╯°□°）╯︵ ┻━┻" "$1" && return
  fi

  printf '%s\n' "$1" >&2
}

require_env() {
  if [[ -z "${HUIX:-}" ]]; then
    notify_error "HUIX is not set"
    exit 1
  fi
}

require_env

shader="$HUIX/scripts/grayscale.frag"

if [[ ! -f "$shader" ]]; then
  notify_error "Shader not found: $shader"
  exit 1
fi

current=$(hyprctl getoption decoration:screen_shader -j | jq -r '.str')

if [[ "$current" == "$shader" ]]; then
  hyprctl keyword decoration:screen_shader "[[EMPTY]]" >/dev/null
  notify-send -u low "Grayscale" "Цвета включены (★^O^★)"
else
  hyprctl keyword decoration:screen_shader "$shader" >/dev/null
  notify-send -u low "Grayscale" "Чёрно-белый режим （-＾〇＾-）"
fi
