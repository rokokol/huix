{
  config,
  pkgs,
  lib,
  huixDir,
  ...
}:

let
  scriptsDir = "${huixDir}/scripts";
  wallpaperDeps = with pkgs; [
    bash
    imagemagick
    awww
    libnotify
    gawk
    findutils
    coreutils
    procps # pidof (проверка hyprlock)
  ];
in
{
  options.custom.hyprland.wallpaperCollage = lib.mkEnableOption "коллаж обоев по таймеру (random-wallpaper.sh)";

  config = lib.mkIf config.custom.hyprland.wallpaperCollage {
    systemd.user.services = {
      "awww-collage" = {
        Unit = {
          Description = "Generate and set wallpaper collage";
          After = [ "graphical-session.target" ];
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.bash}/bin/bash ${scriptsDir}/random-wallpaper.sh";
          Environment = "PATH=${lib.makeBinPath wallpaperDeps}";
        };
      };
    };

    systemd.user.timers = {
      "awww-collage" = {
        Unit.Description = "Timer for awww wallpaper collage";
        Timer = {
          OnActiveSec = "10s";
          OnUnitActiveSec = "5min";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    };
  };
}
