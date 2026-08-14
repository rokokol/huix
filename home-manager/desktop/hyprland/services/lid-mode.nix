{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.rokokol.hyprland;
in
{
  options.rokokol.hyprland.lidNoSleep = lib.mkEnableOption "toggle \"lid blanks the screen instead of suspending\" (laptop only)";

  config = lib.mkIf (cfg.enable && cfg.lidNoSleep) {
    # hyprland.conf is shared by both hosts, so the laptop-only binds live here.
    # settings are applied BEFORE the shared config is sourced, so $mainMod isn't
    # defined yet — the modifier is written literally
    wayland.windowManager.hyprland.settings = {
      bind = [ "SUPER SHIFT, A, exec, ${huixDir}/scripts/lid-mode.sh toggle" ];

      # bindl — fires even when the screen is locked. The device name comes from
      # hyprctl devices; the blanking/waking dpms is done by the script, and close
      # stays silent when the mode is off (then logind handles the lid)
      bindl = [
        ", switch:on:Lid Switch, exec, ${huixDir}/scripts/lid-mode.sh close"
        ", switch:off:Lid Switch, exec, ${huixDir}/scripts/lid-mode.sh open"
      ];
    };
  };
}
