{
  config,
  lib,
  ...
}:

let
  cfg = config.custom.waybar;
in
{
  options.custom.waybar.shader = lib.mkEnableOption "full-screen shaders and software brightness indicator";

  config = lib.mkIf (cfg.enable && cfg.shader) {
    # The module defines custom/shader itself; bar.nix decides where it sits
    programs.screen-shader.waybar = {
      bars = [ "mainBar" ];
      # SIGRTMIN+N to refresh the indicator; must not overlap with notifications.nix (9)
      signal = 8;
    };
  };
}
