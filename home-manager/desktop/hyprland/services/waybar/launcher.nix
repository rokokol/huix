{ config, lib, ... }:

let
  cfg = config.rokokol.waybar;
in
{
  options.rokokol.waybar.launcher = lib.mkEnableOption "an applications button (the same menu as SUPER+W)";

  config = lib.mkIf (cfg.enable && cfg.launcher) {
    programs.waybar.settings.mainBar."custom/launcher" = {
      format = "🐣";
      tooltip = false;
      on-click = config.rokokol.hyprland.menuCommand;
    };
  };
}
