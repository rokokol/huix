{ govnoDir, ... }:

{
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  custom = {
    home.dataDir = govnoDir;

    btop.withCuda = true;

    packages.pc = true;

    hyprland = {
      enable = true;
      monitorScale = "1";
      wallpaperCollage = true;
    };

    waybar = {
      enable = true;
      nvidia = true;
      shader = true;
      temperatureHwmon = "/sys/class/hwmon/hwmon0/temp1_input";
    };
  };
}
