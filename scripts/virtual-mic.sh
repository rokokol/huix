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

# Обычный null-sink: это "чёрная дыра" без вывода в железо, поэтому в наушниках
# тишина. ffmpeg пишет в этот sink, а в приложении выбираешь его монитор
# («Monitor of <name>») как микрофон.
module_id="$(pactl load-module module-null-sink \
  sink_name="$sink_name" \
  sink_properties="device.description=$name")"

cleanup() {
  pactl unload-module "$module_id" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

echo "virtual-mic: $file → «$name» (звука в наушниках не будет)"
echo "virtual-mic: в приложении выбери микрофон «Monitor of $name» (Ctrl+C — стоп)"

# -vn: видео игнорируем, берём только звук. aresample=async сглаживает рассинхрон
# на склейке цикла. Без exec — чтобы по Ctrl+C отработал trap и выгрузил источник.
ffmpeg -hide_banner -loglevel warning \
  -stream_loop -1 -re -i "$file" \
  -vn -af "aresample=async=1000" \
  -f pulse -device "$sink_name" "$name" || true
