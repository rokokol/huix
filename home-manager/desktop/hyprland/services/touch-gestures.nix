{
  config,
  lib,
  pkgs,
  ...
}:

# Hyprland itself gives a touchscreen taps and drags only; the gestures are the plugin's.
# The plugin also warps the pointer to every touch, which is what lets a two-finger swipe
# turn the wheel under the fingers through a virtual pointer: applications without wl_touch
# and the bar's scroll-driven modules scroll and turn that way. A right click is still not
# among the gestures, and the applications answer a long press with their own context menu
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
  # A live gesture: the deltas arrive in swipe units, where the monitor's size maps to
  # gestures.workspace_swipe_distance, so they are turned back into pixels first. Every
  # notch of travel is one wheel event of the same size, sent against the fingers, so the
  # content follows them. hl.exec_cmd spawns without waiting: a Wayland client run
  # synchronously from inside the compositor would wait for the compositor forever
  wheel = mkLuaInline ''
    (function()
      local NOTCH = 24
      local unit, carry = { x = 1, y = 1 }, { x = 0, y = 0 }
      local function notches(v)
        return v >= 0 and math.floor(v / NOTCH) or -math.floor(-v / NOTCH)
      end
      return {
        start = function(ev)
          local distance = hl.get_config("gestures.workspace_swipe_distance")
          unit = { x = ev.monitor.width / distance, y = ev.monitor.height / distance }
          carry = { x = 0, y = 0 }
        end,
        update = function(ev)
          carry.x = carry.x + ev.delta.x * unit.x
          carry.y = carry.y + ev.delta.y * unit.y
          local nx, ny = notches(carry.x), notches(carry.y)
          if nx == 0 and ny == 0 then
            return
          end
          carry.x = carry.x - nx * NOTCH
          carry.y = carry.y - ny * NOTCH
          hl.exec_cmd(string.format("${pkgs.wlrctl}/bin/wlrctl pointer scroll %d %d", -ny * NOTCH, -nx * NOTCH))
        end,
        finish = function() end,
      }
    end)()
  '';
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
          # Two fingers moving at once are the wheel; two fingers held still first are the
          # window drag bound below, because the long press cancels as soon as they move
          {
            pattern = {
              kind = "swipe";
              fingers = 2;
              direction = "swipe";
            };
            action = wheel;
          }
          # The magnifier, anchored under the fingers because the plugin put the pointer
          # there. Live mode reads only the pinch scale; hyprgrass takes the mode from the
          # zoom_level field (main.cpp reads it twice), so both fields carry it and the
          # gesture survives the upstream fix
          {
            pattern = {
              kind = "pinch";
              fingers = 3;
              direction = "pinch";
            };
            action = "cursor_zoom";
            zoom_level = "live";
            mode = "live";
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
