{
  pkgs,
  lib,
  palette,
  ...
}:

{
  # mako doesn't re-read its config by itself (exec-once, no systemd unit) — we
  # nudge it on every activation; outside a graphical session we silently skip.
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

      # Urgency stays colour-coded rather than DDLC-pink: at a glance the level has to read
      # before the theme does. The values come from theme/palette.nix all the same
      "urgency=low" = {
        background-color = palette.okBg;
        text-color = palette.okFg;
        border-color = palette.okLine;
        progress-color = "over ${palette.okSoft}";
        default-timeout = 4000;
      };

      "urgency=normal" = {
        background-color = palette.warnBg;
        text-color = palette.warnFg;
        border-color = palette.warnLine;
        progress-color = "over ${palette.warnSoft}";
        default-timeout = 8000;
      };

      "urgency=critical" = {
        background-color = palette.critBg;
        text-color = palette.critFg;
        border-color = palette.critLine;
        progress-color = "over ${palette.critSoft}";
        default-timeout = 20000;
      };

      # DND, toggle — notify-center.sh dnd
      "mode=do-not-disturb".invisible = 1;

      # Service mode for notify-center.sh clear: makoctl has no history clear,
      # so a restore+dismiss chain wipes it — this mode hides those popups
      "mode=silent".invisible = 1;
    };
  };
}
