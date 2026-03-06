{
  pkgs,
  config,
  lib,
  ...
}:

let
  wallpaperDeps = with pkgs; [
    bash
    imagemagick
    swww
    libnotify
    gawk
    findutils
    coreutils
  ];

  syncDeps = with pkgs; [
    git
    libnotify
    coreutils
    bash
    openssh
  ];
in
{
  systemd.user.services = {
    "sync-hourly" = {
      Unit.Description = "sync.sh hourly";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${config.home.homeDirectory}/huix/home-manager/hyprland/scripts/sync.sh";
        Environment = "PATH=${lib.makeBinPath syncDeps}";
      };
    };

    "swww-collage" = {
      Unit = {
        Description = "Generate and set wallpaper collage";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${config.home.homeDirectory}/huix/home-manager/hyprland/scripts/random_wallpaper.sh";
        Environment = "PATH=${lib.makeBinPath wallpaperDeps}";
      };
    };
  };

  systemd.user.timers = {
    "sync-hourly" = {
      Unit.Description = "Таймер для ежечасного запуска sync.sh";
      Timer = {
        OnCalendar = "hourly";
        OnActiveSec = "10s";
      };
      Install.WantedBy = [ "timers.target" ];
    };

    "swww-collage" = {
      Unit.Description = "Timer for swww wallpaper collage";
      Timer = {
        OnActiveSec = "10s";
        OnUnitActiveSec = "5min";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
