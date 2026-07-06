#!/usr/bin/env bash

set -euo pipefail

# Скриншот в буфер обмена + превью-уведомление, файл удаляется через 5 с.
# $1: region (интерактивное выделение, по умолчанию) | full (весь экран).
mode="${1:-region}"
file="/tmp/shot_$(date +%s).png"

if [[ "$mode" == "region" ]]; then
  geom="$(slurp -b ffffff66 -w 1)" || exit 0
  sleep 0.2
  grim -g "$geom" "$file"
else
  grim "$file"
fi

wl-copy <"$file"
notify-send -i "$file" "Copied"
sleep 5
rm -f "$file"
