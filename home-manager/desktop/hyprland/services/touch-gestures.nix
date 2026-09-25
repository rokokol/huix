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
  # A slider along a screen edge: every 20 px of travel is 5 percent, fingers up raise,
  # and swayosd shows the level. The deltas arrive in swipe units, where the monitor's
  # height maps to gestures.workspace_swipe_distance, so they are turned back into pixels.
  # Every hl.exec_cmd forks the compositor and starts a client that takes tens of
  # milliseconds, so the steps are gathered and sent as one relative change at most once
  # per interval, the rest when the finger lifts: a call per step made the compositor
  # stutter and the level jump as overlapping calls finished out of order
  slider =
    what:
    mkLuaInline ''
      (function()
        local STEP, PERCENT, INTERVAL_MS = 20, 5, 60
        local unit, carry, pending, sent_ms = 1, 0, 0, 0
        local function flush(time_ms)
          if pending ~= 0 then
            hl.exec_cmd(string.format("swayosd-client --${what} %+d", pending * PERCENT))
            pending = 0
          end
          sent_ms = time_ms
        end
        return {
          start = function(ev)
            unit = ev.monitor.height / hl.get_config("gestures.workspace_swipe_distance")
            carry, pending, sent_ms = 0, 0, 0
          end,
          update = function(ev)
            carry = carry - ev.delta.y * unit
            local n = carry >= 0 and math.floor(carry / STEP) or -math.floor(-carry / STEP)
            carry = carry - n * STEP
            pending = pending + n
            if ev.time_ms - sent_ms >= INTERVAL_MS then
              flush(ev.time_ms)
            end
          end,
          finish = function(ev)
            flush(ev and ev.time_ms or 0)
          end,
        }
      end)()
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
          # gesture survives the fix, horriblename/hyprgrass#425; once a lock carries it,
          # zoom_level goes
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
          # mouse: the dispatcher follows the fingers, as a mouse bind follows the pointer. A
          # window moves by its titlebar in tablet mode, so no gesture drags it
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
