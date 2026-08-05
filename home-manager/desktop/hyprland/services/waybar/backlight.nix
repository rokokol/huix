{ config, lib, ... }:

let
  cfg = config.custom.waybar;
in
{
  options.custom.waybar.backlight = lib.mkEnableOption "hardware backlight indicator (brightnessctl)";

  config = lib.mkIf (cfg.enable && cfg.backlight) {
    programs.waybar.settings.mainBar."backlight" = {
      device = "intel_backlight";
      format = "{percent}% {icon}";
      format-icons = [
        "🌑"
        "🌘"
        "🌗"
        "🌖"
        "🌕"
      ];
      on-click = "brightnessctl set 100%";
      on-scroll-up = "brightnessctl set 1%+";
      on-scroll-down = "brightnessctl set 1%-";
    };
  };
}
