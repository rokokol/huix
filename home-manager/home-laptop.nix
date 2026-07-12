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

  custom = {
    home.dataDir = "/home/${rokokolName}";

    packages.laptop = true;

    hyprland = {
      enable = true;
      monitorScale = "1.33";
      touchpadNaturalScroll = true;
      wallpaperImage = "${huixDir}/assets/say-sketch2.webp";
    };

    waybar = {
      enable = true;
      shader = true;
      backlight = true;
      battery = true;
    };
  };

  # Файлы
  home.file.".octaverc".text = ''
    PS1('>> ');
    # отключить предупреждение octave
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
