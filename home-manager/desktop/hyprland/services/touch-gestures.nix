{
  config,
  lib,
  pkgs,
  huixDir,
  ...
}:

# Hyprland itself gives a touchscreen taps and drags only; the gestures are the plugin's.
# The plugin also warps the pointer to every touch, so the magnifier anchors under the
# fingers. Scrolling is not emulated: applications with wl_touch scroll with one finger by
# themselves, and a wheel sent under the fingers only fought them. A right click is not
# among the gestures either, and the applications answer a long press with their own
# context menu
# The switch that turns the device off by hand belongs here too, since this module owns the
# touchscreen: nothing touches the panel and it reports contacts with no coordinates all the
# same, and Hyprland warps the pointer to each of them (scripts/touchscreen.sh says the rest)
let
  cfg = config.rokokol.hyprland;
  inherit (lib.generators) mkLuaInline;
  toLua = lib.generators.toLua { };
  touchscreen = "${huixDir}/scripts/touchscreen.sh";
  run = arg: mkLuaInline "hl.dsp.exec_cmd(${toLua "${touchscreen} ${arg}"})";
  applyState = mkLuaInline "function() hl.exec_cmd(${toLua "${touchscreen} apply"}) end";
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
        # The stock cancel ratio wants a swipe across half the screen; 0.1 switches the
        # workspace after a short one. It also applies to the touchpad's three-finger swipe
        config.gestures.workspace_swipe_cancel_ratio = 0.1;

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
          # The bar's scroll-driven modules are out of a finger's reach: the bar takes the
          # touch sequence and answers no wheel while a touch is down, so the brightness and
          # the volume have sliders along the edges instead
          (slide "l" (slider "brightness"))
          (slide "r" (slider "output-volume"))
          # The magnifier, anchored under the fingers because the plugin put the pointer
          # there; live mode follows the pinch, so it needs no zoom level
          {
            pattern = {
              kind = "pinch";
              fingers = 3;
              direction = "pinch";
            };
            action = "cursor_zoom";
            mode = "live";
          }
        ];

        bind = [
          # The touchscreen reports contacts with no coordinates at all when nothing touches
          # it, and Hyprland takes the pointer — with follow_mouse the focus — to each of them.
          # The noise comes and goes and the gestures are worth keeping otherwise, so the
          # device is switched off by hand when it starts (see the script's own header)
          {
            _args = [
              "SUPER + SHIFT + T"
              (run "toggle")
            ];
          }
        ];

        # A config reload enables every input device again, and the compositor's start
        # follows a session that may have left the touchscreen off
        on = [
          {
            _args = [
              "hyprland.start"
              applyState
            ];
          }
          {
            _args = [
              "config.reloaded"
              applyState
            ];
          }
        ];

        "plugin.hyprgrass.bind" = [
          # An edge swipe from the bottom shows and hides the special workspace, as SUPER+S
          # does; one from the top enters and leaves fullscreen, because a fullscreen window
          # carries no titlebar to leave it by
          (edge "d" "u" ''hl.dsp.workspace.toggle_special("magic")'')
          (edge "u" "d" ''hl.dsp.window.fullscreen({ mode = "fullscreen" })'')
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
