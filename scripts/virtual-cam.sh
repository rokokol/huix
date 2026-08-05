#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
virtual-cam — loops a video or image into a virtual camera (v4l2loopback).
In the app you select the "Virtual Camera" camera

Usage:
  virtual-cam [options] <video-or-image>

Options:
  -d, --device <path>   output device
                        (default: looked up by the "Virtual Camera" label, otherwise /dev/video10)
  -f, --fps <n>         frame rate (default 30)
  -m, --mirror          mirror horizontally
                        (if the app doesn't mirror the preview itself)
  -h, --help            show this help

The camera carries no sound — v4l2 is video only. For sound there's virtual-mic

Examples:
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
    -d | --device) device="${2:?--device requires a value}"; shift 2 ;;
    -f | --fps) fps="${2:?--fps requires a value}"; shift 2 ;;
    -m | --mirror) flip=1; shift ;;
    --) shift; break ;;
    -*) echo "virtual-cam: unknown option: $1" >&2; usage >&2; exit 1 ;;
    *) break ;;
  esac
done

file="${1:-}"
if [[ -z "$file" ]]; then
  echo "virtual-cam: no file given" >&2
  usage >&2
  exit 1
fi
if [[ ! -r "$file" ]]; then
  echo "virtual-cam: file not found or not readable: $file" >&2
  exit 1
fi

# Device: explicit flag → "Virtual Camera" label → /dev/video10
if [[ -z "$device" ]]; then
  device="$(v4l2-ctl --list-devices 2>/dev/null \
    | awk '/Virtual Camera/{getline; gsub(/^[[:space:]]+/,""); print; exit}')"
  device="${device:-/dev/video10}"
fi
if [[ ! -e "$device" ]]; then
  echo "virtual-cam: device $device does not exist — is the v4l2loopback module loaded?" >&2
  exit 1
fi

mime="$(file --brief --mime-type "$file")"

echo "virtual-cam: $file ($mime) → $device  @${fps}fps  (Ctrl+C — stop)"

# Native resolution, even dimensions only (needed for yuv420p). Constant fps + PTS
# recomputed from the frame number: timestamps are strictly monotonic and continuous
# across the loop boundary, otherwise the stream stutters/drops at each splice
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
    echo "virtual-cam: unsupported file type: $mime" >&2
    exit 1
    ;;
esac
