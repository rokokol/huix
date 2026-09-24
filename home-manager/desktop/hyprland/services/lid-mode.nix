{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.rokokol.hyprland;
  inherit (lib.generators) mkLuaInline;
  script = "${huixDir}/scripts/lid-mode.sh";
  run = arg: mkLuaInline "hl.dsp.exec_cmd(${lib.generators.toLua { } "${script} ${arg}"})";
in
{
  options.rokokol.hyprland.lidNoSleep = lib.mkEnableOption "toggle \"lid blanks the screen instead of suspending\" (laptop only)";

  config = lib.mkIf (cfg.enable && cfg.lidNoSleep) {
    # hyprland.lua is shared by both hosts, so the laptop-only binds live here
    wayland.windowManager.hyprland.settings.bind = [
      {
        _args = [
          "SUPER + SHIFT + A"
          (run "toggle")
        ];
      }
      # locked: fires with the screen locked too. The device name comes from hyprctl
      # devices; the blanking and waking dpms is done by the script, and close stays
      # silent when the mode is off (then logind handles the lid)
      {
        _args = [
          "switch:on:Lid Switch"
          (run "close")
          { locked = true; }
        ];
      }
      {
        _args = [
          "switch:off:Lid Switch"
          (run "open")
          { locked = true; }
        ];
      }
    ];
  };
}
