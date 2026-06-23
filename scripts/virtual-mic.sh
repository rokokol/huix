#!/usr/bin/env bash
# virtual-mic — крутит звук в виртуальный микрофон. Справка: --help.
set -euo pipefail

usage() {
  cat <<'EOF'
virtual-mic — создаёт виртуальный микрофон (PipeWire) и крутит в него аудиофайл
или звук из видео на репите. В приложении выбираешь микрофон «Virtual-Mic».

Реальный микрофон не трогается, в наушники ничего не выводится и устройства
вывода не создаётся (используется module-pipe-source — чистый источник из FIFO).
Источник живёт, пока команда запущена; по Ctrl+C он выгружается.

Использование:
  virtual-mic [опции] <аудио-или-видео-файл>

Опции:
  -n, --name <имя>   имя микрофона в списке устройств (по умолчанию «Virtual-Mic»)
  -h, --help         показать эту справку

Примеры:
  virtual-mic track.mp3
  virtual-mic --name "Fake Mic" clip.mp4
EOF
}

name="Virtual-Mic"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help) usage; exit 0 ;;
    -n | --name) name="${2:?--name требует значение}"; shift 2 ;;
    --) shift; break ;;
    -*) echo "virtual-mic: неизвестная опция: $1" >&2; usage >&2; exit 1 ;;
    *) break ;;
  esac
done

file="${1:-}"
if [[ -z "$file" ]]; then
  echo "virtual-mic: не указан файл" >&2
  usage >&2
  exit 1
fi
if [[ ! -r "$file" ]]; then
  echo "virtual-mic: файл не найден или нет доступа: $file" >&2
  exit 1
fi

source_name="virtual_mic"
rate=48000
channels=2

# Создаваемые ресурсы. Объявлены заранее и пустыми, чтобы cleanup мог их убирать
# с проверкой «создан ли» — даже если что-то упадёт на полпути инициализации.
fifo=""
module_id=""
ff_pid=""

# cleanup — best-effort: errexit выключен, каждый ресурс убирается отдельно и
# только если он был создан. Поэтому функция не падает на полпути и не делает
# ничего опасного при пустых переменных.
cleanup() {
  set +e
  [[ -n "$ff_pid" ]]    && kill "$ff_pid" 2>/dev/null
  [[ -n "$module_id" ]] && pactl unload-module "$module_id" 2>/dev/null
  [[ -n "$fifo" ]]      && rm -f "$fifo"
}
# Ставим trap ДО создания ресурсов: если упадёт mkfifo/load-module, повисший
# FIFO/модуль всё равно подчистится. HUP важен для закрытия терминала — без него
# (как и при любом неперехваченном сигнале) EXIT-trap не выполнится.
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

fifo="$(mktemp -u /tmp/virtual-mic.XXXXXX.fifo)"
mkfifo "$fifo"

# module-pipe-source создаёт только источник (микрофон), без sink/вывода в
# железо. Звук берёт из FIFO; формат должен совпадать с тем, что пишет ffmpeg.
module_id="$(pactl load-module module-pipe-source \
  source_name="$source_name" \
  file="$fifo" \
  format=s16le rate="$rate" channels="$channels" \
  source_properties="device.description=$name")"

echo "virtual-mic: $file → микрофон «$name» (в наушниках тишина, вывод не создаётся)"
echo "virtual-mic: выбери микрофон «$name» в приложении (Ctrl+C — стоп)"

# ffmpeg в фоне + wait: wait прерывается trap'ом, тот добивает ffmpeg в cleanup —
# так процесс не осиротеет. По Ctrl+C ffmpeg может напечатать одну строку, это ок.
# -vn: только звук. aresample=async сглаживает рассинхрон на склейке цикла.
# Сырой s16le льём в FIFO (-y — перезаписать уже созданный нами файл-пайп).
ffmpeg -hide_banner -loglevel error -y \
  -stream_loop -1 -re -i "$file" \
  -vn -af "aresample=async=1000" \
  -f s16le -ar "$rate" -ac "$channels" "$fifo" &
ff_pid=$!
wait "$ff_pid" || true
