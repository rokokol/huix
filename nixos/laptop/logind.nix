{ ... }:

{
  # "no" makes inhibitor locks effective: lid-mode.sh (SUPER+SHIFT+A) can block lid suspend;
  # HandleLidSwitch stays at default so the lid still suspends outside Hyprland (greeter, tty)
  services.logind.settings.Login.LidSwitchIgnoreInhibited = "no";
}
