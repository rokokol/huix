#!/usr/bin/env bash

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

target=$(($(date +%s) + secs))
wake_human=$(date -d "@$target" '+%H:%M %d.%m')
echo "Сон до $wake_human. Подъём — Ctrl+C, чтобы остановить звон."
notify-send -u low "Будильник заведён （-＾〇＾-）" "Подъём в $wake_human" || true

# rtcwake -m no только ЗАВОДИТ будильник RTC, не усыпляя сам. Прямой
# `rtcwake -m mem` пишет в /sys/power/state в обход systemd и на десктопе с GPU
# падает с "write error" — поэтому сам сон делаем через `systemctl suspend`,
# чтобы отработали systemd-хуки (в т.ч. nvidia).
sudo "$RTCWAKE" -m no -s "$secs"
systemctl suspend

# `systemctl suspend` возвращает управление сразу после инициации сна; процесс
# замораживается вместе с машиной и продолжится уже после пробуждения. Ждём,
# пока не настанет назначенное время (на случай, если suspend не сработал —
# просто досидим до срока наяву).
while [ "$(date +%s)" -lt "$target" ]; do
  sleep 5
done

# ---- проснулись -> звеним ----
wpctl set-mute @DEFAULT_AUDIO_SINK@ 0 || true
wpctl set-volume @DEFAULT_AUDIO_SINK@ 1.0 || true
notify-send -u critical "ПОДЪЁМ (*≧m≦*)" "Помни, зачем ты это сделал, уебище" || true

# Звук крутим в фоне, а сами ждём нажатие любой клавиши.
(while :; do pw-play "$ALARM_SOUND" || sleep 1; done) &
ring_pid=$!

read -rsn1 -p "Нажми любую клавишу, чтобы выключить будильник... " _ || true

kill "$ring_pid" 2>/dev/null || true     # остановить цикл
pkill -P "$ring_pid" 2>/dev/null || true # добить текущий pw-play
echo
echo "Будильник выключен."
