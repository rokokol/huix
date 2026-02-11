#!/usr/bin/env bash

# Папка для временных превью
tmp_dir="/tmp/cliphist_previews"
mkdir -p "$tmp_dir"

# Получаем список и форматируем его для rofi
# Мы ищем строки с 'binary' и генерируем для них иконки
cliphist list | while read -r line; do
  if echo "$line" | grep -q "\[\[ binary"; then
    id=$(echo "$line" | cut -f1)
    img_path="$tmp_dir/$id.png"

    # Генерируем превью, если его еще нет
    if [ ! -f "$img_path" ]; then
      cliphist decode "$id" >"$img_path" 2>/dev/null
    fi

    # Выводим строку с иконкой для rofi
    echo -en "$line\0icon\x1f$img_path\n"
  else
    echo "$line"
  fi
done | rofi -dmenu -i -show-icons -display-columns 2 -p "📋" | cliphist decode | wl-copy
