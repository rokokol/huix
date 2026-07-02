{ pkgs, ... }:

{
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

      # Режим "не беспокоить": попапы не рендерятся, но уведомления копятся в
      # истории. Тумблер — notify-center.sh dnd (SUPER+SHIFT+N / ПКМ по
      # индикатору waybar). Режим живёт в рантайме mako и сбрасывается с сессией.
      "mode=do-not-disturb".invisible = 1;

      # Служебный режим notify-center.sh: под ним restore/dismiss-цепочки
      # перекладывают историю (удаление записи, показ снова), не мигая попапами.
      "mode=silent".invisible = 1;
    };
  };
}
