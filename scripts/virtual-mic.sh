#!/usr/bin/env bash
# Создаёт виртуальный микрофон (PipeWire) и крутит в него аудиофайл или звук из
# видео на репите. В приложении выбираешь микрофон "Virtual-Mic". Реальный
# микрофон не трогается. Виртуальный источник живёт, пока команда запущена;
# по Ctrl+C он выгружается.
# Зависимости (ffmpeg, pactl) кладёт обёртка virtual-mic.nix.
#
# Использование:
#   virtual-mic <аудио-или-видео-файл>
# Имя источника можно переопределить: VMIC_NAME (по умолчанию "Virtual-Mic").

set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: virtual-mic <audio-or-video-file>" >&2
  exit 1
fi

file="$1"

if [[ ! -r "$file" ]]; then
  echo "virtual-mic: файл не найден или нет доступа: $file" >&2
  exit 1
fi

name="${VMIC_NAME:-Virtual-Mic}"
sink_name="virtual_mic"

# media.class=Audio/Source/Virtual — нода появляется именно как микрофон (а не
# как "Monitor of ..."), в этот источник ffmpeg и пишет звук.
module_id="$(pactl load-module module-null-sink \
  media.class=Audio/Source/Virtual \
  sink_name="$sink_name" \
  channel_map=front-left,front-right \
  sink_properties="device.description=$name")"

cleanup() {
  pactl unload-module "$module_id" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "virtual-mic: $file → микрофон «$name»"
echo "virtual-mic: выбери этот микрофон в приложении (Ctrl+C чтобы остановить)"

# -vn: видео игнорируем, берём только звук. aresample=async сглаживает рассинхрон
# на склейке цикла. Без exec — чтобы по Ctrl+C отработал trap и выгрузил источник.
ffmpeg -hide_banner -loglevel warning \
  -stream_loop -1 -re -i "$file" \
  -vn -af "aresample=async=1000" \
  -f pulse -device "$sink_name" "$name" || true
