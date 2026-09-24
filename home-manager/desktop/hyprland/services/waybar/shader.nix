{ config, lib, ... }:

let
  cfg = config.rokokol.waybar;
in
{
  options.rokokol.waybar.shader = lib.mkEnableOption "full-screen shaders and software brightness indicator";

  # Whether the indicator shows a rainbow when nothing is on is the module's own
  # waybar.idleIcon, set per host in home-<host>.nix
  config = lib.mkIf (cfg.enable && cfg.shader) {
    programs.screen-shader.waybar = {
      enable = true;
      bars = [ "mainBar" ];
      signal = 8;
    };
  };
}
