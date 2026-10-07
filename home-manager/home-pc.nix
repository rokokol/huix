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

  wayland.windowManager.hyprland.settings =
    let
      cfg = config.rokokol.hyprland;
    in
    {
      # The primary is pinned to the left edge; Hyprland puts every "auto" monitor to the right
      # of the pinned ones. With no pin, the order in which DRM finds the connectors decides
      # the layout, and that order changes between boots
      monitor = [
        {
          output = cfg.primaryMonitor;
          mode = cfg.monitorMode;
          position = "0x0";
          scale = cfg.monitorScale;
        }
      ];

      # With nothing said, Hyprland stretches the pen tablet over every monitor
      device = {
        name = "gaomon-gaomon-tablet_s630";
        output = cfg.primaryMonitor;
      };
    };
}
