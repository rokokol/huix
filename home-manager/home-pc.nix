{ pkgs, govnoDir, ... }:

{
  programs.home-manager.enable = true;
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  _module.args.btopPackage = pkgs.btop-cuda;

  custom = {
    home.dataDir = govnoDir;

    packages.pc = true;

    hyprland = {
      enable = true;
      monitorScale = "1";
      kbOptions = "grp:win_space_toggle";
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
