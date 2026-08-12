{
  pkgs,
  palette,
  ...
}:

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

      max-history = 50;

      border-radius = 8;
      border-size = 3;

      icons = 1;
      max-icon-size = 48;

      # Chats and the web, in effect: a sender that omits the urgency hint (Telegram and Firefox
      # both do) matches no [urgency=…] section at all, so the global block is the only place
      # that can style it, and whatever is left unset here stays on mako's stock blue.
      # Its own ground rather than a level's, since the category is orthogonal to loudness
      background-color = palette.natsuki;
      text-color = palette.ink;
      border-color = palette.plum;
      progress-color = "over ${palette.plum}";
      default-timeout = 12000;

      # The three levels are told apart by how loud the colour is, not by hue — the palette has
      # no green/amber/red. Grounds stay deliberately close; the border carries the level.
      # A progress bar only ever appears if the sender passes a "value" hint, which nothing in
      # huix does — the lines are here so a third-party one doesn't get mako's off-palette blue
      "urgency=low" = {
        background-color = palette.paper;
        text-color = palette.ink;
        border-color = palette.dot;
        progress-color = "over ${palette.dot}";
        default-timeout = 4000;
      };

      "urgency=normal" = {
        background-color = palette.dot;
        text-color = palette.ink;
        border-color = palette.sayori;
        progress-color = "over ${palette.sayori}";
        default-timeout = 8000;
      };

      # bow, not the yuri border: the one level that has to shout keeps the palette's only red
      "urgency=critical" = {
        background-color = palette.blush;
        text-color = palette.yuriShadow;
        border-color = palette.yuri;
        progress-color = "over ${palette.bow}";
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
