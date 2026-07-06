{ pkgs, ... }:

# Persistent Wayland clipboard daemon. A user-session service, so it lives in
# HM alongside the other graphical-session units (mako, hypridle, swayosd),
# not in nixos/. wl-clipboard (wl-copy/wl-paste) comes from other HM modules.
{
  home.packages = [ pkgs.wl-clip-persist ];

  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Persistent clipboard for Wayland";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
