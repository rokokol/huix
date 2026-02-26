{ pkgs, ... }:

{
  systemd.user.services = {
    "sync-hourly" = {
      Unit.Description = "sync.sh hourly";
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash /home/rokokol/huix/home-manager/hyprland/scripts/sync.sh";
      };
    };

    "sync-on-logout" = {
      Unit = {
        Description = "sync.sh on logout";
        PartOf = [ "graphical-session.target" ];
      };
      Service = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "${pkgs.coreutils}/bin/true";
        ExecStop = "${pkgs.bash}/bin/bash /home/rokokol/huix/home-manager/hyprland/scripts/sync.sh";
      };
      Install = {
        WantedBy = [ "graphical-session.target" ];
      };
    };
  };

  systemd.user.timers."sync-hourly" = {
    Unit.Description = "Таймер для ежечасного запуска sync.sh";
    Timer = {
      OnCalendar = "hourly";
      Persistent = true;
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
