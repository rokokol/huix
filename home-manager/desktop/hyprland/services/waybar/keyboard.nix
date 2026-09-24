{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.rokokol.waybar;
in
{
  options.rokokol.waybar.keyboard = lib.mkEnableOption "an on-screen keyboard button (wvkbd through tablet-mode.sh)";

  config = lib.mkIf (cfg.enable && cfg.keyboard) {
    # No exec: wvkbd has no state to ask for, the button only toggles it
    programs.waybar.settings.mainBar."custom/keyboard" = {
      format = "⌨️";
      tooltip = false;
      on-click = "${huixDir}/scripts/tablet-mode.sh keyboard toggle";
    };
  };
}
