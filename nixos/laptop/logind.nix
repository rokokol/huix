{ ... }:

{
  # По умолчанию logind усыпляет по крышке, ИГНОРИРУЯ inhibitor-локи
  # (LidSwitchIgnoreInhibited=yes). С no лок handle-lid-switch начинает работать —
  # на этом держится режим "крышка гасит экран, а не усыпляет"
  # (scripts/lid-mode.sh, бинд SUPER+SHIFT+A, см. hyprland/services/lid-mode.nix).
  # Само поведение крышки остаётся дефолтным (suspend), так что вне сессии
  # Hyprland — на логин-экране, в tty — ноутбук засыпает как обычно.
  services.logind.settings.Login.LidSwitchIgnoreInhibited = "no";
}
