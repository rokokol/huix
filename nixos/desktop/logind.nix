{ config, lib, ... }:

lib.mkIf config.rokokol.workstation.enable {
  # Power key → Hyprland (XF86PowerOff → rofi-power.sh); without ignore logind would poweroff
  # immediately
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # tiny_power_button claims the same ACPI power button and signals init with SIGRTMIN+4 on a press,
  # which is a poweroff before the menu can open, so the device stays with the button driver
  boot.blacklistedKernelModules = [ "tiny_power_button" ];

  # Reduce the default 30s post-wakeup holdoff to 2s so lid-close triggers immediately
  services.logind.settings.Login.HoldoffTimeoutSec = "2s";
}
