{ config, lib, ... }:

let
  cfg = config.rokokol.waybar;
in
{
  options.rokokol.waybar.battery = lib.mkEnableOption "battery indicator";

  config = lib.mkIf (cfg.enable && cfg.battery) {
    programs.waybar.settings.mainBar."battery" = {
      format = "{capacity}% {icon}";
      format-icons = [ "🔋" ];
    };
  };
}
