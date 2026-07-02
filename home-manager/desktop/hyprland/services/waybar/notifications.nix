{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.custom.waybar;
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
      # Сигнал покрывает наши действия, интервал — приход новых уведомлений:
      # у mako нет хука "на новое уведомление"
      interval = 5;
      signal = notifSignal;
      on-click = "${huixDir}/scripts/rofi-notify.sh";
      on-click-right = "${huixDir}/scripts/notify-center.sh dnd toggle";
      # -h: ручное закрытие мимо истории, как СКМ по попапу
      on-click-middle = "makoctl dismiss -a -h";
    };
  };
}
