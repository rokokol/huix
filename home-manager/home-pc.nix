{ config, ... }:

{
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  rokokol = {
    btop.withCuda = true;

    packages.pc = true;

    opencode.server = true;

    hyprland = {
      enable = true;
      primaryMonitor = "DP-1";
      workspaceWheelAnimationStyle = "fade";
      monitorScale = 1.0;
      wallpaperCollage = false; # for Felix wallspaper :3
    };

    waybar = {
      enable = true;
      nvidia = true;
      shader = true;
      temperatureHwmon = "/sys/class/hwmon/hwmon0/temp1_input";
    };
  };

  # Fixed positions: with "auto", the order in which DRM finds the connectors decides which
  # screen is on the left, and that order changes between boots
  wayland.windowManager.hyprland.settings.monitor = [
    {
      output = config.rokokol.hyprland.primaryMonitor;
      mode = "preferred";
      position = "0x0";
      scale = 1.0;
    }
    {
      output = "HDMI-A-1";
      mode = "preferred";
      position = "1920x0";
      scale = 1.0;
    }
  ];
}
