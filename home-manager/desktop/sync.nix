{
  pkgs,
  lib,
  huixDir,
  ...
}:

let
  scriptsDir = "${huixDir}/scripts";
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
  };
}
