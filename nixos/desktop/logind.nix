{ ... }:

{
  # The power key is handled not by logind (poweroff by default) but by the
  # compositor: Hyprland catches XF86PowerOff and shows a rofi power menu
  # (scripts/rofi-power.sh). Without ignore the system would power off
  # immediately, bypassing the menu
  services.logind.settings.Login.HandlePowerKey = "ignore";

  # By default logind ignores lid events for 30 seconds after wakeup (waiting
  # for docks/monitors to be detected) — a quick "open-close" of the lid looks
  # like a refusal to sleep. 2s is enough to probe hotplug devices, while
  # closing the lid triggers almost immediately. The PC has no lid — the option
  # is harmless
  services.logind.settings.Login.HoldoffTimeoutSec = "2s";
}
