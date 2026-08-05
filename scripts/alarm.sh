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

# rtcwake -m no only ARMS the RTC alarm without suspending itself. A direct
# `rtcwake -m mem` writes to /sys/power/state bypassing systemd and on a desktop
# with a GPU fails with "write error" — so we do the suspend itself via
# `systemctl suspend`, so systemd hooks (incl. nvidia) run.
sudo "$RTCWAKE" -m no -s "$secs"
systemctl suspend

# `systemctl suspend` returns control right after the suspend is initiated; the
# process is frozen together with the machine and resumes only after wake-up. We
# wait until the scheduled time arrives (in case suspend didn't fire — we just
# sit awake until the deadline).
while [ "$(date +%s)" -lt "$target" ]; do
  sleep 5
done

# ---- woke up -> ring ----
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 || true
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 || true
notify-send -u critical "WAKE UP (*≧m≦*)" "Remember why you did this, you wretch" || true

# The ringing runs in a foreground loop and stops ONLY on Ctrl+C: SIGINT is caught
# by a trap that sets a flag — and the loop exits. No "press any key". pw-play also
# receives SIGINT and terminates, after which the trap runs, the flag becomes 1,
# and the while exits immediately.
stop=0
trap 'stop=1' INT
echo "Ringing. Press Ctrl+C to turn the alarm off…"
while [ "$stop" -eq 0 ]; do
  pw-play "$ALARM_SOUND" 2>/dev/null || true
done

echo
echo "Alarm turned off"
