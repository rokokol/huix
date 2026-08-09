{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.rokokol.waybar;
  notifSignal = 9;
in
{
  imports = [ ../mako.nix ];

  config = lib.mkIf cfg.enable {
    home.sessionVariables.WAYBAR_NOTIF_SIGNAL = toString notifSignal;

    programs.waybar.settings.mainBar."custom/notifications" = {
      exec = "${huixDir}/scripts/notify-center.sh status";
      return-type = "json";
      format = "{}";
      # The signal covers our actions, the interval covers incoming notifications:
      # mako has no "on new notification" hook
      interval = 5;
      signal = notifSignal;
      on-click = "${huixDir}/scripts/rofi-notify.sh";
      on-click-right = "${huixDir}/scripts/notify-center.sh dnd toggle";
      # -h: manual close bypassing history, like MMB on a popup
      on-click-middle = "makoctl dismiss -a -h";
    };
  };
}
