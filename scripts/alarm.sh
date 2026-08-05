#!/usr/bin/env bash
set -euo pipefail

RTCWAKE="/run/current-system/sw/bin/rtcwake"
ALARM_SOUND="${ALARM_SOUND:-/run/current-system/sw/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga}"

usage() {
  cat <<'EOF'
alarm — suspends the computer for a given time, then wakes it and rings

Usage:
  alarm <hours>    sleep N hours (fractions ok: 8 or 7.5), then ring
  alarm -h | --help

The ringing stops only via Ctrl+C
EOF
}

case "${1:-}" in
-h | --help | "")
  usage
  exit 0
  ;;
esac

hours="${1}"
if ! printf '%s' "$hours" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
  echo "Hours must be a number, for example 8 or 7.5" >&2
  exit 1
fi

secs=$(awk -v h="$hours" 'BEGIN { printf "%d", h * 3600 }')
if [ "$secs" -lt 60 ]; then
  echo "Too little: need at least 60 seconds (≈0.017 hours)" >&2
  exit 1
fi

target=$(($(date +%s) + secs))
wake_human=$(date -d "@$target" '+%H:%M %d.%m')

echo "Sleeping until $wake_human. Wake-up — Ctrl+C to stop the ringing."
notify-send -u low "Alarm set （-＾〇＾-）" "Wake-up at $wake_human" || true

# -m no arms the RTC alarm only; systemctl suspend does the actual sleep so nvidia hooks run
sudo "$RTCWAKE" -m no -s "$secs"
systemctl suspend

# wait in case suspend didn't fire — sit awake until the deadline
while [ "$(date +%s)" -lt "$target" ]; do
  sleep 5
done

# ---- woke up -> ring ----
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 || true
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 || true
notify-send -u critical "WAKE UP (*≧m≦*)" "Remember why you did this, you wretch" || true

# SIGINT trap sets stop=1; pw-play also gets SIGINT and exits, then the loop checks the flag
stop=0
trap 'stop=1' INT
echo "Ringing. Press Ctrl+C to turn the alarm off…"
while [ "$stop" -eq 0 ]; do
  pw-play "$ALARM_SOUND" 2>/dev/null || true
done

echo
echo "Alarm turned off"
