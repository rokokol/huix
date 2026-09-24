{
  config,
  lib,
  pkgs,
  ...
}:

# Hyprland itself gives a touchscreen taps and drags only; the gestures are the plugin's.
# The plugin also warps the pointer to every touch, so the magnifier anchors under the
# fingers. Scrolling is not emulated: applications with wl_touch scroll with one finger by
# themselves, and a wheel sent under the fingers only fought them. A right click is not
# among the gestures either, and the applications answer a long press with their own
# context menu
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
  # A live gesture in notches: the deltas arrive in swipe units, where the monitor's size
  # maps to gestures.workspace_swipe_distance, so they are turned back into pixels first;
  # the axis is locked by the first notch, so a slanted finger drives one thing; every
  # step pixels of travel then run onNotch with nx or ny, the notches on that axis and
  # their sign. hl.exec_cmd spawns without waiting: a Wayland client run synchronously
  # from inside the compositor would wait for the compositor forever
  notched =
    step: onNotch:
    mkLuaInline ''
      (function()
        local STEP = ${toString step}
        local unit, carry, axis = { x = 1, y = 1 }, { x = 0, y = 0 }, nil
        local function notches(v)
          return v >= 0 and math.floor(v / STEP) or -math.floor(-v / STEP)
        end
        return {
          start = function(ev)
            local distance = hl.get_config("gestures.workspace_swipe_distance")
            unit = { x = ev.monitor.width / distance, y = ev.monitor.height / distance }
            carry, axis = { x = 0, y = 0 }, nil
          end,
          update = function(ev)
            carry.x = carry.x + ev.delta.x * unit.x
            carry.y = carry.y + ev.delta.y * unit.y
            axis = axis or (math.abs(carry.x) >= STEP and "x") or (math.abs(carry.y) >= STEP and "y") or nil
            if not axis then
              return
            end
            local n = notches(carry[axis])
            if n == 0 then
              return
            end
            carry[axis] = carry[axis] - n * STEP
            local nx, ny = 0, 0
            if axis == "x" then
              nx = n
            else
              ny = n
            end
            ${onNotch}
          end,
          finish = function() end,
        }
      end)()
    '';
  # A slider along a screen edge: three percent a notch, fingers up raise, and swayosd
  # shows the level
  slider =
    what:
    notched 20 ''
      for _ = 1, math.abs(ny) do
        hl.exec_cmd("swayosd-client --${what} " .. (ny < 0 and "+3" or "-3"))
      end
    '';
  slide = origin: action: {
    pattern = {
      kind = "edge";
      inherit origin;
      direction = "vertical";
    };
    inherit action;
  };
in
{
  options.rokokol.hyprland.touchGestures = lib.mkEnableOption "touchscreen gestures (hyprgrass, laptop only)";

  config = lib.mkIf (cfg.enable && cfg.touchGestures) {
    wayland.windowManager.hyprland = {
      plugins = with pkgs.hyprlandPlugins; [ hyprgrass ];

      settings = {
        config.plugin.hyprgrass = {
          # One knob for every threshold: a swipe and a pinch are recognised after
          # 150 / sensitivity pixels, a long press tolerates 100 / sensitivity of slip.
          # Higher made an edge slider start sooner but let a three-finger swipe pass for
          # a pinch, so the magnifier fired in place of a workspace switch
          sensitivity = 4.0;
          long_press_delay = 400;
          # Wide enough for a thumb to land in from the bezel: the sliders live here
          edge_margin = 32;
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
          # The bar's scroll-driven modules are out of a finger's reach: the bar takes the
          # touch sequence and answers no wheel while a touch is down, so the brightness and
          # the volume have sliders along the edges instead
          (slide "l" (slider "brightness"))
          (slide "r" (slider "output-volume"))
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
          # A tap past rofi closes it. rofi holds the keyboard exclusively, so a tap on
          # another surface moves no focus and rofi itself sees nothing; the plugin put the
          # pointer under the finger, and this bind lets the tap through to whatever it hit
          {
            pattern = {
              kind = "tap";
              fingers = 1;
            };
            non_consuming = true;
            action = mkLuaInline ''
              function()
                local pos = hl.get_cursor_pos()
                for _, l in ipairs(hl.get_layers({ namespace = "rofi" })) do
                  if l.mapped and (pos.x < l.x or pos.x > l.x + l.w or pos.y < l.y or pos.y > l.y + l.h) then
                    hl.exec_cmd("pkill -x rofi")
                  end
                end
              end
            '';
          }
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
