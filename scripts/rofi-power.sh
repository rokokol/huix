#!/usr/bin/env bash

# Меню питания в rofi (dmenu): выключение, перезагрузка, спящий режим,
# блокировка, выход из сессии. Вешается на кнопку питания (XF86PowerOff)
# и на бинд в hyprland.conf. Логику выхода/сна делают systemctl/loginctl,
# скрипт — только представление и подтверждение.

set -euo pipefail

# Пункты: "эмодзи подпись|действие". Действие — ключ из case ниже.
options=$(
  cat <<'EOF'
🔒 Блокировка|lock
😴 Спящий режим|suspend
🔁 Перезагрузка|reboot
🚪 Выход из сессии|logout
⏻ Выключение|poweroff
EOF
)

choice=$(printf '%s\n' "$options" | cut -d'|' -f1 |
  rofi -dmenu -i -p "Питание" -mesg "Что делаем? (⊃‿⊂)" \
    -theme-str 'window { width: 300px; }') || exit 0

[[ -n "$choice" ]] || exit 0

# По видимой подписи находим действие (вторую колонку).
action=$(printf '%s\n' "$options" | grep -F "$choice" | head -n1 | cut -d'|' -f2)

case "$action" in
lock) loginctl lock-session ;;
suspend) systemctl suspend ;;
reboot) systemctl reboot ;;
logout) hyprctl dispatch exit ;;
poweroff) systemctl poweroff ;;
*) exit 0 ;;
esac
