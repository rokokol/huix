{ config, lib, ... }:

let
  cfg = config.custom.waybar;
in
{
  options.custom.waybar.battery = lib.mkEnableOption "индикатор батареи";

  config = lib.mkIf (cfg.enable && cfg.battery) {
    programs.waybar.settings.mainBar."battery" = {
      format = "{capacity}% {icon}";
      format-icons = [ "🔋" ];
    };
  };
}
