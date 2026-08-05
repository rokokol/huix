{ ... }:

{
  # Power key → Hyprland (XF86PowerOff → rofi-power.sh); without ignore logind would poweroff immediately
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # Reduce the default 30s post-wakeup holdoff to 2s so lid-close triggers immediately
  services.logind.settings.Login.HoldoffTimeoutSec = "2s";
}
