#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
virtual-mic — creates a virtual microphone (PipeWire) and loops an audio file or a
video's sound into it. In the app you select the "Virtual-Mic" microphone.

The real microphone is untouched, nothing is output to the headphones and no output
device is created (module-pipe-source is used — a pure source from a FIFO). The
source lives while the command runs; on Ctrl+C it is unloaded.

Usage:
  virtual-mic [options] <audio-or-video-file>

Options:
  -n, --name <name>  microphone name in the device list (default "Virtual-Mic")
  -h, --help         show this help

Examples:
  virtual-mic track.mp3
  virtual-mic --name "Fake Mic" clip.mp4
EOF
}

name="Virtual-Mic"

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  -n | --name)
    name="${2:?--name requires a value}"
    shift 2
    ;;
  --)
    shift
    break
    ;;
  -*)
    echo "virtual-mic: unknown option: $1" >&2
    usage >&2
    exit 1
    ;;
  *) break ;;
  esac
done

file="${1:-}"
if [[ -z "$file" ]]; then
  echo "virtual-mic: no file given" >&2
  usage >&2
  exit 1
fi
if [[ ! -r "$file" ]]; then
  echo "virtual-mic: file not found or not readable: $file" >&2
  exit 1
fi

source_name="virtual_mic"
rate=48000
channels=2

# Resources we create. Declared up front and empty so cleanup can remove them with
# a "was it created" check — even if something fails midway through initialization.
fifo=""
module_id=""
ff_pid=""

# cleanup — best-effort: errexit is off, each resource is removed separately and
# only if it was created. So the function doesn't fail midway and does nothing
# dangerous with empty variables.
cleanup() {
  set +e
  [[ -n "$ff_pid" ]] && kill "$ff_pid" 2>/dev/null
  [[ -n "$module_id" ]] && pactl unload-module "$module_id" 2>/dev/null
  [[ -n "$fifo" ]] && rm -f "$fifo"
}
trap cleanup EXIT
trap 'exit 130' INT TERM HUP

fifo="$(mktemp -u /tmp/virtual-mic.XXXXXX.fifo)"
mkfifo "$fifo"

module_id="$(pactl load-module module-pipe-source \
  source_name="$source_name" \
  file="$fifo" \
  format=s16le rate="$rate" channels="$channels" \
  source_properties="device.description=$name")"

echo "virtual-mic: $file → microphone \"$name\" (silence in the headphones, no output created)"
echo "virtual-mic: select the microphone \"$name\" in the app (Ctrl+C — stop)"

ffmpeg -hide_banner -loglevel error -y \
  -stream_loop -1 -re -i "$file" \
  -vn -af "aresample=async=1000" \
  -f s16le -ar "$rate" -ac "$channels" "$fifo" &
ff_pid=$!
wait "$ff_pid" || true
