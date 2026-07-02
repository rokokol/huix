{ pkgs, lib, ... }:

{
  # mako сам конфиг не перечитывает (exec-once, без systemd-юнита) — пинаем на
  # каждой активации; вне графической сессии молча скипаем.
  home.activation.reloadMako = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.mako}/bin/makoctl reload 2>/dev/null || true
  '';

  services.mako = {
    enable = true;

    settings = {
      anchor = "top-right";
      font = "Doki 12";
      padding = "15";

      on-button-right = "exec makoctl menu -n $id -- ${pkgs.rofi}/bin/rofi -dmenu -p 💌";
      on-button-left = "invoke-default-action";
      on-button-middle = "dismiss";

      default-timeout = 6500;
      max-history = 50;

      border-radius = 8;
      border-size = 3;

      icons = 1;
      max-icon-size = 48;

      "urgency=low" = {
        background-color = "#e8f5e9";
        text-color = "#1b5e20";
        border-color = "#4caf50";
        progress-color = "over #c8e6c9";
        default-timeout = 4000;
      };

      "urgency=normal" = {
        background-color = "#fff8e1";
        text-color = "#825e00";
        border-color = "#ffb300";
        progress-color = "over #ffe082";
        default-timeout = 8000;
      };

      "urgency=critical" = {
        background-color = "#ffebee";
        text-color = "#b71c1c";
        border-color = "#e53935";
        progress-color = "over #ffcdd2";
        default-timeout = 20000;
      };

      # DND, тумблер — notify-center.sh dnd
      "mode=do-not-disturb".invisible = 1;

      # Служебный режим для notify-center.sh clear: у makoctl нет очистки
      # истории, её выедает restore+dismiss-цепочка — режим прячет эти попапы
      "mode=silent".invisible = 1;
    };
  };
}
