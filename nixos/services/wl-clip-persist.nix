{ pkgs, ... }:

{
  systemd.user.services.wl-clip-persist = {
    description = "Persistent clipboard for Wayland";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
      Restart = "always";
      RestartSec = 5;
    };
  };
}
