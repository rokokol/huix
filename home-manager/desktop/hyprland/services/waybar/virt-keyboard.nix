{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.rokokol.waybar;
  # SIGRTMIN+N, sent by tablet-mode.sh when the mode changes; declared once, here
  tabletSignal = 10;
in
{
  options.rokokol.waybar.virtKeyboard = lib.mkEnableOption "an on-screen keyboard button, shown in tablet mode (wvkbd through tablet-mode.sh)";

  config = lib.mkIf (cfg.enable && cfg.virtKeyboard) {
    home.sessionVariables.HUIX_TABLET_SIGNAL = toString tabletSignal;

    # The button is the mode's indicator: it is there when the laptop is folded and gone
    # when it is not, so the mode needs no notification
    programs.waybar.settings.mainBar."custom/virt-keyboard" = {
      exec = "${huixDir}/scripts/tablet-mode.sh virt-keyboard status";
      return-type = "json";
      format = "{}";
      tooltip = false;
      signal = tabletSignal;
      on-click = "${huixDir}/scripts/tablet-mode.sh virt-keyboard toggle";
    };
  };
}
