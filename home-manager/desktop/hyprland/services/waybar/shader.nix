{ config, lib, ... }:

let
  cfg = config.rokokol.waybar;
in
{
  options.rokokol.waybar.shader = lib.mkEnableOption "full-screen shaders and software brightness indicator";

  config = lib.mkIf (cfg.enable && cfg.shader) {
    programs.screen-shader.waybar = {
      enable = true;
      bars = [ "mainBar" ];
      signal = 8;
    };
  };
}
