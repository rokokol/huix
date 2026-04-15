{
  huixDir,
  pkgs,
  lib,
  ...
}:

let
  scriptsDir = ./scripts;
  wallpaperDeps = with pkgs; [
    bash
    imagemagick
    awww
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
      Unit = {
        Description = "sync.sh hourly";
        After = [
          "graphical-session.target"
          "ssh-agent.service"
        ];
        PartOf = [ "graphical-session.target" ];
        Wants = [ "ssh-agent.service" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${scriptsDir}/sync.sh";
        TimeoutStartSec = "2min";
        Environment = [
          "PATH=${lib.makeBinPath syncDeps}"
          "HUIX=${huixDir}"
          "SSH_ASKPASS_REQUIRE=force"
        ];
      };
    };

    "awww-collage" = {
      Unit = {
        Description = "Generate and set wallpaper collage";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash ${scriptsDir}/random_wallpaper.sh";
        Environment = "PATH=${lib.makeBinPath wallpaperDeps}";
      };
    };
  };

  systemd.user.timers = {
    "sync-hourly" = {
      Unit = {
        Description = "Таймер для ежечасного запуска sync.sh";
        PartOf = [ "graphical-session.target" ];
      };
      Timer = {
        OnCalendar = "hourly";
        OnActiveSec = "15s";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };

    "awww-collage" = {
      Unit.Description = "Timer for awww wallpaper collage";
      Timer = {
        OnActiveSec = "10s";
        OnUnitActiveSec = "5min";
      };
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
