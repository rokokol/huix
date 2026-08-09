{
  huixDir,
  rokokolName,
  ...
}:

{
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  rokokol = {
    home.dataDir = "/home/${rokokolName}";

    packages.laptop = true;

    # The dialog costs two shell-spawning labels at 10 Hz plus a render loop — not on battery
    hyprlock.dialog = false;

    hyprland = {
      enable = true;
      monitorScale = "1.33";
      touchpadNaturalScroll = true;
      lidNoSleep = true;
      wallpaperImage = "${huixDir}/assets/say-sketch2.webp";
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
    # disable octave warning
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
