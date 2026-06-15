#!/usr/bin/env bash
# alarm — усыпляет компьютер на заданное время, а после будит и звенит.
#
# Зависимости: rtcwake (util-linux), pw-play + wpctl (pipewire/wireplumber),
# notify-send (libnotify), awk, coreutils. Звук можно переопределить через
# переменную окружения ALARM_SOUND.
set -euo pipefail

RTCWAKE="/run/current-system/sw/bin/rtcwake"
ALARM_SOUND="${ALARM_SOUND:-/run/current-system/sw/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga}"

usage() {
  cat <<'EOF'
alarm — усыпляет компьютер на заданное время, а после будит и звенит.

Использование:
  alarm <минуты>     спать N минут (можно дробно: 90 или 7.5), потом звенеть
  alarm -h | --help

Звон отключается через Ctrl+C.
EOF
}

case "${1:-}" in
  -h | --help | "")
    usage
    exit 0
    ;;
esac

minutes="${1}"
if ! printf '%s' "$minutes" | grep -Eq '^[0-9]+([.][0-9]+)?$'; then
  echo "Минуты должны быть числом, например 90 или 7.5" >&2
  exit 1
fi

secs=$(awk -v m="$minutes" 'BEGIN { printf "%d", m * 60 }')
if [ "$secs" -lt 60 ]; then
  echo "Слишком мало: нужно хотя бы 60 секунд" >&2
  exit 1
fi

wake_human=$(date -d "+$secs seconds" '+%H:%M %d.%m')
echo "Сон до $wake_human. Подъём — Ctrl+C, чтобы остановить звон."
notify-send -u critical "⏰ Будильник заведён" "Подъём в $wake_human" || true
sleep 3

# rtcwake -m mem усыпляет в RAM, заводит RTC и возвращает управление только
# после того, как машина проснётся в назначенный срок.
sudo "$RTCWAKE" -m mem -s "$secs"

# ---- проснулись -> звеним ----
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 || true
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 || true
notify-send -u critical "⏰ ПОДЪЁМ" "Ctrl+C, чтобы выключить будильник" || true

while :; do
  pw-play "$ALARM_SOUND" || sleep 1
done
