#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
virtual-cam — крутит видео или картинку в виртуальную камеру (v4l2loopback)
на репите. В приложении выбираешь камеру "Virtual Camera".

Использование:
  virtual-cam [опции] <видео-или-картинка>

Опции:
  -d, --device <путь>   устройство вывода
                        (по умолчанию: ищется по метке "Virtual Camera", иначе /dev/video10)
  -f, --fps <n>         частота кадров (по умолчанию 30)
  -m, --mirror          отзеркалить по горизонтали
                        (если приложение само не зеркалит превью)
  -h, --help            показать эту справку

Звук камера не передаёт — v4l2 это только видео. Для звука есть virtual-mic.

Примеры:
  virtual-cam clip.mp4
  virtual-cam --mirror --fps 24 clip.mp4
  virtual-cam -d /dev/video11 picture.png
EOF
}

device=""
fps=30
flip=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    -d | --device) device="${2:?--device требует значение}"; shift 2 ;;
    -f | --fps) fps="${2:?--fps требует значение}"; shift 2 ;;
    -m | --mirror) flip=1; shift ;;
    --) shift; break ;;
    -*) echo "virtual-cam: неизвестная опция: $1" >&2; usage >&2; exit 1 ;;
    *) break ;;
  esac
done

file="${1:-}"
if [[ -z "$file" ]]; then
  echo "virtual-cam: не указан файл" >&2
  usage >&2
  exit 1
fi
if [[ ! -r "$file" ]]; then
  echo "virtual-cam: файл не найден или нет доступа: $file" >&2
  exit 1
fi

# Устройство: явный флаг → метка "Virtual Camera" → /dev/video10.
if [[ -z "$device" ]]; then
  device="$(v4l2-ctl --list-devices 2>/dev/null \
    | awk '/Virtual Camera/{getline; gsub(/^[[:space:]]+/,""); print; exit}')"
  device="${device:-/dev/video10}"
fi
if [[ ! -e "$device" ]]; then
  echo "virtual-cam: устройство $device не существует — модуль v4l2loopback не загружен?" >&2
  exit 1
fi

mime="$(file --brief --mime-type "$file")"

echo "virtual-cam: $file ($mime) → $device  @${fps}fps  (Ctrl+C — стоп)"

# Родное разрешение, только чётные размеры (нужны для yuv420p). Постоянный fps +
# пересчёт PTS из номера кадра: таймстампы строго монотонны и непрерывны через
# границу зацикливания, иначе на каждой склейке поток дёргается/обрывается.
vf="fps=${fps}"
[[ "$flip" == 1 ]] && vf+=",hflip"
vf+=",format=yuv420p,scale=trunc(iw/2)*2:trunc(ih/2)*2,setpts=N/(${fps}*TB)"

case "$mime" in
  image/*)
    exec ffmpeg -hide_banner -loglevel error \
      -re -loop 1 -i "$file" -vf "$vf" -f v4l2 "$device"
    ;;
  video/*)
    exec ffmpeg -hide_banner -loglevel error \
      -stream_loop -1 -re -i "$file" -vf "$vf" -an -fflags +genpts \
      -f v4l2 "$device"
    ;;
  *)
    echo "virtual-cam: неподдерживаемый тип файла: $mime" >&2
    exit 1
    ;;
esac
