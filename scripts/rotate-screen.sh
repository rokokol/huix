#!/usr/bin/env bash
# hyprctl keyword monitor replaces the whole rule and has no "change one field" form, so the
# mode, position and scale are read back from hyprctl monitors -j and written out again with
# the new transform. The touch and pen transforms are separate keywords that start at 0 and
# never follow the monitor, so they are set beside it every time
# Needs jq, hyprctl and internal_monitor from lib/hyprland.sh; auto needs stdbuf and
# monitor-sensor as well
set -euo pipefail

usage() {
  cat <<'EOF'
rotate-screen.sh — rotate a monitor together with its touch and pen input (Hyprland transform)

  rotate-screen.sh [-m MONITOR] set N     transform N: 0 upright, 1 90°, 2 180°, 3 270°
  rotate-screen.sh [-m MONITOR] next      one step through 0, 1, 2, 3 and around
  rotate-screen.sh [-m MONITOR] prev      one step back
  rotate-screen.sh [-m MONITOR] status    print the current transform number
  rotate-screen.sh [-m MONITOR] auto      follow the accelerometer until stopped

  -m MONITOR   a name from hyprctl monitors (default: the focused monitor; for auto, the
               built-in panel)

auto reads monitor-sensor from iio-sensor-proxy and maps normal, left-up, bottom-up and
right-up to 0, 1, 2 and 3; it runs until killed, which is what the huix-auto-rotate user
unit does. The touch and pen transforms are global in Hyprland, so rotating one monitor
of several turns them as well
Nothing here reaches the network
Exit 0 done, 1 when the monitor is not there or Hyprland refuses, 2 on a usage error
EOF
}

fail() { # the thing asked about is wrong
  printf 'rotate-screen.sh: %s\n' "$1" >&2
  exit 1
}

die() { # the request itself is wrong
  printf 'rotate-screen.sh: %s\n' "$1" >&2
  exit 2
}

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
. "$HERE/lib/hyprland.sh"

monitor=""

# One line per call: name width height refresh x y scale transform. Empty when the monitor
# is not there; with no name, the focused monitor
monitor_state() {
  hyprctl monitors -j | jq -r --arg m "$monitor" '
    (if $m == "" then map(select(.focused)) else map(select(.name == $m)) end)
    | .[0] | select(. != null)
    | "\(.name) \(.width) \(.height) \(.refreshRate) \(.x) \(.y) \(.scale) \(.transform)"'
}

# apply NAME WIDTH HEIGHT REFRESH X Y SCALE TRANSFORM
apply() {
  hyprctl keyword monitor "$1,$2x$3@$4,$5x$6,$7,transform,$8" >/dev/null
  hyprctl keyword input:touchdevice:transform "$8" >/dev/null
  hyprctl keyword input:tablet:transform "$8" >/dev/null
}

# rotate_to TRANSFORM, on the monitor chosen above
rotate_to() {
  local state
  state=$(monitor_state)
  [ -n "$state" ] || fail "no such monitor: ${monitor:-the focused one}"
  # shellcheck disable=SC2086 # the state is eight space-separated fields on purpose
  set -- $state "$1"
  apply "$1" "$2" "$3" "$4" "$5" "$6" "$7" "$9"
}

current_transform() {
  local state
  state=$(monitor_state)
  [ -n "$state" ] || fail "no such monitor: ${monitor:-the focused one}"
  printf '%s\n' "${state##* }"
}

cmd_set() {
  (($# == 1)) || die "set needs one transform number"
  case "$1" in
    0 | 1 | 2 | 3) rotate_to "$1" ;;
    *) die "a transform is 0, 1, 2 or 3, not $1" ;;
  esac
}

cmd_next() {
  local t
  t=$(current_transform)
  rotate_to $(((t + 1) % 4))
}

cmd_prev() {
  local t
  t=$(current_transform)
  rotate_to $(((t + 3) % 4))
}

cmd_status() {
  current_transform
}

cmd_auto() {
  local line orientation t
  [ -n "$monitor" ] || monitor=$(internal_monitor)
  [ -n "$monitor" ] || fail "no built-in panel to follow the sensor with"
  # The first line reports the orientation the sensor already has, every later one a
  # change; the pipe is line-buffered so a change lands before the next one
  stdbuf -oL monitor-sensor --accel | while IFS= read -r line; do
    case "$line" in
      *"orientation changed: "* | *"(orientation: "*) ;;
      *) continue ;;
    esac
    orientation=${line##*: }
    orientation=${orientation%)}
    case "$orientation" in
      normal) t=0 ;;
      left-up) t=1 ;;
      bottom-up) t=2 ;;
      right-up) t=3 ;;
      *) continue ;;
    esac
    rotate_to "$t"
  done
}

while (($#)); do
  case "$1" in
    -m)
      (($# >= 2)) || die "-m needs a monitor name"
      monitor=$2
      shift 2
      ;;
    -h | --help | help)
      usage
      exit 0
      ;;
    -*) die "no such flag: $1" ;;
    *) break ;;
  esac
done

cmd="${1:-}"
(($# == 0)) || shift
case "$cmd" in
  set) cmd_set "$@" ;;
  next) cmd_next "$@" ;;
  prev) cmd_prev "$@" ;;
  status) cmd_status "$@" ;;
  auto) cmd_auto "$@" ;;
  -h | --help | help) usage ;;
  '')
    usage >&2
    exit 2
    ;;
  *)
    printf 'rotate-screen.sh: no such subcommand: %s\n\n' "$cmd" >&2
    usage >&2
    exit 2
    ;;
esac
