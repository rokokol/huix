{
  config,
  lib,
  pkgs,
  ...
}:

# Hyprland itself gives a touchscreen taps and drags only; the gestures are the plugin's.
# A right click is not among them: a tap does not move the pointer, so nothing could click
# under the fingers, and the applications answer a long press with their own context menu
let
  cfg = config.rokokol.hyprland;
  inherit (lib.generators) mkLuaInline;
  edge = origin: direction: action: {
    pattern = {
      kind = "edge";
      inherit origin direction;
    };
    action = mkLuaInline action;
  };
in
{
  options.rokokol.hyprland.touchGestures = lib.mkEnableOption "touchscreen gestures (hyprgrass, laptop only)";

  config = lib.mkIf (cfg.enable && cfg.touchGestures) {
    wayland.windowManager.hyprland = {
      plugins = with pkgs.hyprlandPlugins; [ hyprgrass ];

      settings = {
        config.plugin.hyprgrass = {
          sensitivity = 4.0;
          long_press_delay = 400;
          edge_margin = 10;
          resize_on_border_long_press = true;
        };

        "plugin.hyprgrass.gesture" = [
          {
            pattern = {
              kind = "swipe";
              fingers = 3;
              direction = "horizontal";
            };
            action = "workspace";
          }
        ];

        "plugin.hyprgrass.bind" = [
          # An edge swipe from the bottom opens the menu; one from the top enters and leaves
          # fullscreen, because a fullscreen window carries no titlebar to leave it by
          (edge "d" "u" "hl.dsp.exec_cmd(${lib.generators.toLua { } cfg.menuCommand})")
          (edge "u" "d" ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'')
          (edge "r" "l" ''hl.dsp.focus({ workspace = "+1" })'')
          (edge "l" "r" ''hl.dsp.focus({ workspace = "-1" })'')
          # mouse: the dispatcher follows the fingers, as a mouse bind follows the pointer
          {
            pattern = {
              kind = "longpress";
              fingers = 2;
            };
            action = mkLuaInline "hl.dsp.window.drag()";
            mouse = true;
          }
          {
            pattern = {
              kind = "longpress";
              fingers = 3;
            };
            action = mkLuaInline "hl.dsp.window.resize()";
            mouse = true;
          }
        ];
      };
    };
  };
}
