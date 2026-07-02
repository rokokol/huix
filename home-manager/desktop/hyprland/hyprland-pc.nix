{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";

    settings = {
      monitor = [
        ",preferred,auto,1"
      ];

      input = {
        kb_layout = "us,ru";
        kb_variant = "";
        kb_options = "grp:win_space_toggle";

        follow_mouse = 1;

        sensitivity = 0;
      };
    };
  };

  custom.waybar = {
    enable = true;
    nvidia = true;
    shader = true;
    temperatureHwmon = "/sys/class/hwmon/hwmon0/temp1_input";
  };

  imports = [
    ./services/wallpaper_collager.nix
    ./services/hyprland-packages.nix
    ./services/waybar
  ];
}
