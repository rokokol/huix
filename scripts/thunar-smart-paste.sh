#!/usr/bin/env bash
# Вставка содержимого буфера обмена как файла в текущую папку Thunar.
# Вызывается из custom action (Ctrl+Shift+V) с %f первым аргументом.
# Картинка -> img.png (расширение по MIME), текст (в т.ч. строка-путь) -> text.txt.
# Файловые операции Thunar (Ctrl+V/Ctrl+C/Ctrl+X) этот скрипт не трогает.
set -euo pipefail

dir="${1:-$PWD}"
# если Thunar передал выделенный файл, а не папку — берём его директорию
[ -d "$dir" ] || dir="$(dirname "$dir")"

types="$(wl-paste --list-types 2>/dev/null || true)"

# ищем mime картинки; расширение выводим из subtype
img_mime=""
while IFS= read -r t; do
  case "$t" in
    image/*)
      img_mime="$t"
      break
      ;;
  esac
done <<<"$types"

if [ -n "$img_mime" ]; then
  base="img"
  sub="${img_mime#image/}"
  case "$sub" in
    jpeg) ext="jpg" ;;
    svg+xml) ext="svg" ;;
    x-*) ext="${sub#x-}" ;;
    *) ext="$sub" ;;
  esac
  mime="$img_mime"
elif grep -qx 'text/plain;charset=utf-8' <<<"$types"; then
  base="text"
  ext="txt"
  mime="text/plain;charset=utf-8"
elif grep -qx 'text/plain' <<<"$types"; then
  base="text"
  ext="txt"
  mime="text/plain"
elif grep -qx 'text/uri-list' <<<"$types"; then
  # буфер = копия файла; по требованию пишем путь как текстовый файл, а не копируем файл
  base="text"
  ext="txt"
  mime="text/uri-list"
else
  # буфер пуст или тип не поддерживается — молча выходим, без уведомлений
  exit 0
fi

# уникальное имя: img.png, img-1.png, img-2.png, ...
name="$base.$ext"
i=1
while [ -e "$dir/$name" ]; do
  name="$base-$i.$ext"
  i=$((i + 1))
done

wl-paste --type "$mime" >"$dir/$name"
