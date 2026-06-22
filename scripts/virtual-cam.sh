#!/usr/bin/env bash
# Льёт видео или картинку в виртуальную камеру (v4l2loopback) на репите.
# Логика тонкая: определить тип файла и запустить ffmpeg в нужном режиме.
# Зависимости (ffmpeg, file, v4l2-ctl) кладёт обёртка virtual-cam.nix.
#
# Использование:
#   virtual-cam <файл> [устройство]
# По умолчанию устройство ищется по метке "Virtual Camera", иначе /dev/video10.

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: virtual-cam <video-or-image> [/dev/videoN]" >&2
  exit 1
fi

file="$1"

if [[ ! -r "$file" ]]; then
  echo "virtual-cam: файл не найден или нет доступа: $file" >&2
  exit 1
fi

# Устройство: явный аргумент → метка "Virtual Camera" → /dev/video10.
if [[ $# -ge 2 ]]; then
  dev="$2"
else
  dev="$(v4l2-ctl --list-devices 2>/dev/null \
    | awk '/Virtual Camera/{getline; gsub(/^[[:space:]]+/,""); print; exit}')"
  dev="${dev:-/dev/video10}"
fi

if [[ ! -e "$dev" ]]; then
  echo "virtual-cam: устройство $dev не существует — модуль v4l2loopback не загружен?" >&2
  exit 1
fi

mime="$(file --brief --mime-type "$file")"

echo "virtual-cam: $file ($mime) → $dev  (Ctrl+C чтобы остановить)"

# Чётные размеры обязательны для yuv420p.
common_filter="format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2"

case "$mime" in
  image/*)
    exec ffmpeg -hide_banner -loglevel warning \
      -re -loop 1 -i "$file" \
      -vf "$common_filter" -r 30 \
      -f v4l2 "$dev"
    ;;
  video/*)
    exec ffmpeg -hide_banner -loglevel warning \
      -stream_loop -1 -re -i "$file" \
      -vf "$common_filter" -an \
      -f v4l2 "$dev"
    ;;
  *)
    echo "virtual-cam: неподдерживаемый тип файла: $mime" >&2
    exit 1
    ;;
esac
