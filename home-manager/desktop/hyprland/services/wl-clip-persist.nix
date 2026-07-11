{ pkgs, ... }:

# Демон персистентного буфера обмена Wayland. Сервис пользовательской сессии,
# поэтому живёт в HM рядом с остальными graphical-session юнитами (mako,
# hypridle, swayosd), а не в nixos/. wl-clipboard (wl-copy/wl-paste) приходит
# из других HM-модулей.
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
