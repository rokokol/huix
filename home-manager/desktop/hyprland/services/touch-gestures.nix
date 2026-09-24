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
in
{
  options.rokokol.hyprland.touchGestures = lib.mkEnableOption "touchscreen gestures (hyprgrass, laptop only)";

  config = lib.mkIf (cfg.enable && cfg.touchGestures) {
    wayland.windowManager.hyprland = {
      plugins = with pkgs.hyprlandPlugins; [ hyprgrass ];

      settings = {
        # touch_gestures is the plugin's hyprlang namespace; its Lua config calls it hyprgrass
        plugin.touch_gestures = {
          sensitivity = "4.0";
          long_press_delay = 400;
          edge_margin = 10;
          resize_on_border_long_press = true;
        };

        "hyprgrass-gesture" = [ "swipe, 3, horizontal, workspace" ];

        # edge:X:Y is a swipe from edge X in direction Y. From the top edge, in and out of
        # fullscreen: a fullscreen window carries no titlebar to leave it by
        "hyprgrass-bind" = [
          ", edge:d:u, exec, ${cfg.menuCommand}"
          ", edge:u:d, fullscreen, 0"
          ", edge:r:l, workspace, +1"
          ", edge:l:r, workspace, -1"
        ];

        # The m flag makes the dispatcher a mouse one, as bindm does for a mouse button
        "hyprgrass-bindm" = [
          ", longpress:2, movewindow"
          ", longpress:3, resizewindow"
        ];
      };
    };
  };
}
