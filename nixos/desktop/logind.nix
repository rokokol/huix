{ ... }:

{
  # Кнопку питания обрабатывает не logind (по умолчанию — poweroff), а
  # композитор: Hyprland ловит XF86PowerOff и показывает rofi-меню питания
  # (scripts/rofi-power.sh). Без ignore система выключалась бы сразу, минуя меню.
  services.logind.settings.Login.HandlePowerKey = "ignore";
}
