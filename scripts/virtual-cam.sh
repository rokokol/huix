#!/usr/bin/env bash
# Льёт видео или картинку в виртуальную камеру (v4l2loopback) на репите.
# Логика тонкая: определить тип файла и запустить ffmpeg в нужном режиме.
# Зависимости (ffmpeg, file, v4l2-ctl) кладёт обёртка virtual-cam.nix.
#
# Использование:
#   virtual-cam <файл> [устройство]
# По умолчанию устройство ищется по метке "Virtual Camera", иначе /dev/video10.
# VCAM_FPS  — частота кадров (по умолчанию 30).
# VCAM_FLIP=1 — отзеркалить по горизонтали (если приложение само не зеркалит).

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

fps="${VCAM_FPS:-30}"

mime="$(file --brief --mime-type "$file")"

echo "virtual-cam: $file ($mime) → $dev  (Ctrl+C чтобы остановить)"

# Родное разрешение, только чётные размеры (нужны для yuv420p). Постоянный fps +
# пересчёт PTS из номера кадра: таймстампы строго монотонны и непрерывны через
# границу зацикливания — иначе на каждой склейке цикла муксер v4l2 ловит
# немонотонные DTS и поток дёргается/обрывается.
common_filter="fps=${fps}"
[[ "${VCAM_FLIP:-0}" == "1" ]] && common_filter+=",hflip"
common_filter+=",format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2,setpts=N/(${fps}*TB)"

case "$mime" in
  image/*)
    exec ffmpeg -hide_banner -loglevel warning \
      -re -loop 1 -i "$file" \
      -vf "$common_filter" \
      -f v4l2 "$dev"
    ;;
  video/*)
    exec ffmpeg -hide_banner -loglevel warning \
      -stream_loop -1 -re -i "$file" \
      -vf "$common_filter" -an \
      -fflags +genpts \
      -f v4l2 "$dev"
    ;;
  *)
    echo "virtual-cam: неподдерживаемый тип файла: $mime" >&2
    exit 1
    ;;
esac
