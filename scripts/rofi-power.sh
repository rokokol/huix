#!/usr/bin/env bash

# Меню питания в rofi (script-modi «power»): блокировка, спящий режим,
# перезагрузка, выход из сессии, выключение. Вешается на кнопку питания
# (XF86PowerOff) и на бинд в hyprland.conf. Эмодзи режима (⚡) задаётся в
# home-manager/programs/rofi/default.nix (display-power) — единый источник
# эмодзи режимов, здесь его нет. Логику делают systemctl/loginctl/hyprctl.

set -euo pipefail

# Пункты списка: «подпись|действие». Действие — ключ из case ниже.
list_options() {
  cat <<'EOF'
🔒 Блокировка|lock
😴 Спящий режим|suspend
🔁 Перезагрузка|reboot
🚪 Выход из сессии|logout
⏻ Выключение|poweroff
EOF
}

# Вне rofi — лаунчер: режим «power», эмодзи-подпись берётся из конфига rofi.
if [[ -z "${ROFI_RETV:-}" ]]; then
  exec rofi -show power -modi "power:$0" -mesg "Что делаем? (⊃‿⊂)"
fi

# Выбран пункт — действие rofi кладёт в ROFI_INFO. Пустой ROFI_INFO — первый
# вызов: печатаем пункты (видимая подпись + скрытое действие в info).
case "${ROFI_INFO:-}" in
lock)     loginctl lock-session ;;
suspend)  systemctl suspend ;;
reboot)   systemctl reboot ;;
logout)   hyprctl dispatch exit ;;
poweroff) systemctl poweroff ;;
"")
  while IFS='|' read -r label action; do
    printf '%s\0info\x1f%s\n' "$label" "$action"
  done < <(list_options)
  ;;
esac
