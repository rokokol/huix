{
  pkgs,
  huixDir,
  rokokolName,
  ...
}:

{
  programs.home-manager.enable = true;
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  _module.args.btopPackage = pkgs.btop;

  custom = {
    home.dataDir = "/home/${rokokolName}";

    packages.laptop = true;

    hyprland = {
      enable = true;
      monitorScale = "1.33";
      kbOptions = "grp:shifts_toggle,ctrl:swapcaps";
      touchpadNaturalScroll = true;
      wallpaperImage = "${huixDir}/asssets/laptop_wallpaper.png";
    };

    waybar = {
      enable = true;
      shader = true;
      backlight = true;
      battery = true;
    };
  };

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
