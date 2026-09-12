{ govnoDir, ... }:

{
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  rokokol = {
    home.dataDir = govnoDir;

    btop.withCuda = true;

    packages.pc = true;

    hyprland = {
      enable = true;
      monitorScale = "1";
      wallpaperCollage = false; # for Felix wallspaper :3
      startupArgs = [
        "dex -a"
        "super-productivity"
      ];
    };

    waybar = {
      enable = true;
      nvidia = true;
      shader = true;
      temperatureHwmon = "/sys/class/hwmon/hwmon0/temp1_input";
    };
  };
}
