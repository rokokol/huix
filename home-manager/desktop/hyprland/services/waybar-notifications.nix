{ huixDir, ... }:

let
  # SIGRTMIN+N, которым notify-center.sh пинает waybar обновить индикатор.
  # Экспортируется как WAYBAR_NOTIF_SIGNAL — единый источник правды (тот же
  # паттерн, что WAYBAR_SHADER_SIGNAL = 8 в waybar-pc.nix; не пересекаться).
  notifSignal = 9;
in
{
  home.sessionVariables.WAYBAR_NOTIF_SIGNAL = toString notifSignal;

  # Общий для обоих хостов центр уведомлений. Хост добавляет
  # "custom/notifications" в свой modules-right и стилизует в своём style
  # (attrsets настроек waybar сливаются модульной системой HM).
  programs.waybar.settings.mainBar."custom/notifications" = {
    exec = "${huixDir}/scripts/notify-center.sh status";
    return-type = "json";
    format = "{}";
    # Сигнал покрывает наши действия (dnd/clear/delete/restore), интервал —
    # приход новых уведомлений: у mako нет хука "на новое уведомление".
    interval = 5;
    signal = notifSignal;
    on-click = "${huixDir}/scripts/rofi-notify.sh";
    on-click-right = "${huixDir}/scripts/notify-center.sh dnd toggle";
    on-click-middle = "makoctl dismiss -a";
    # Листание истории попапом-превью: вниз — старее, вверх — свежее.
    on-scroll-down = "${huixDir}/scripts/notify-center.sh nav down";
    on-scroll-up = "${huixDir}/scripts/notify-center.sh nav up";
  };
}
