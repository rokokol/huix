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

      # Попап-превью листания истории (notify-center.sh nav, колесо на
      # waybar-модуле). history=0 — не попадает в историю НИКАК (ни по таймауту,
      # ни при ручном закрытии), иначе листание засоряло бы то, что листает.
      "category=huix-history-preview".history = 0;

      # ...и превью видно даже под DND: раз пользователь листает историю, он
      # явно хочет её видеть. Секция должна идти ПОСЛЕ "mode=do-not-disturb",
      # чтобы её invisible=0 победил — Nix сериализует ключи по алфавиту, и
      # "mode=do-not-disturb category=..." сортируется после "mode=do-not-disturb".
      "mode=do-not-disturb category=huix-history-preview".invisible = 0;
    };
  };
}
