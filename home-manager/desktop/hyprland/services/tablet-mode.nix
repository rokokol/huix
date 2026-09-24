{
  config,
  lib,
  pkgs,
  huixDir,
  palette,
  ...
}:

# The mode itself is two user units and the switch binds; what happens on the way in and
# out is tablet-mode.sh, which is also what the waybar virt-keyboard button calls
let
  cfg = config.rokokol.hyprland;
  scriptsDir = "${huixDir}/scripts";
  inherit (palette) bare;
  inherit (lib.generators) mkLuaInline;
  run = cmd: mkLuaInline "hl.dsp.exec_cmd(${lib.generators.toLua { } cmd})";
  rotateDeps = with pkgs; [
    bash
    coreutils # stdbuf, which keeps the sensor pipe line-buffered
    jq
    hyprland
    iio-sensor-proxy # monitor-sensor
  ];
in
{
  options.rokokol.hyprland = {
    tabletMode = lib.mkEnableOption "the folded-laptop mode: auto-rotation, titlebars and the on-screen keyboard (laptop only)";

    tabletModeSwitch = lib.mkOption {
      type = lib.types.str;
      default = "Intel Virtual Switches";
      description = "the switch device that reports SW_TABLET_MODE, as hyprctl devices names it";
    };
  };

  config = lib.mkIf (cfg.enable && cfg.tabletMode) {
    home.packages = with pkgs; [
      wvkbd
      evtest
    ];

    # Spelled once: the binds below and tablet-mode.sh sync read the same name
    home.sessionVariables.HUIX_TABLET_SWITCH = cfg.tabletModeSwitch;

    wayland.windowManager.hyprland.settings = {
      bind = [
        {
          _args = [
            "SUPER + M"
            (run "${scriptsDir}/rotate-screen.sh next")
          ];
        }
        {
          _args = [
            "SUPER + SHIFT + M"
            (run "${scriptsDir}/tablet-mode.sh toggle")
          ];
        }
        # locked: fires with the screen locked too
        {
          _args = [
            "switch:on:${cfg.tabletModeSwitch}"
            (run "${scriptsDir}/tablet-mode.sh on")
            { locked = true; }
          ];
        }
        {
          _args = [
            "switch:off:${cfg.tabletModeSwitch}"
            (run "${scriptsDir}/tablet-mode.sh off")
            { locked = true; }
          ];
        }
      ];

      # The switch reports changes only, and a reload resets the transform and the
      # titlebars, so sync runs at the start and after every reload
      on =
        map
          (event: {
            _args = [
              event
              (mkLuaInline ''
                function()
                  hl.exec_cmd(${lib.generators.toLua { } "${scriptsDir}/tablet-mode.sh sync"})
                end'')
            ];
          })
          [
            "hyprland.start"
            "config.reloaded"
          ];
    };

    # Neither unit is wanted by a target: tablet-mode.sh starts and stops them
    systemd.user.services = {
      huix-auto-rotate = {
        Unit = {
          Description = "Turn the screen with the accelerometer (rotate-screen.sh auto)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          ExecStart = "${pkgs.bash}/bin/bash ${scriptsDir}/rotate-screen.sh auto";
          Restart = "on-failure";
          Environment = [ "PATH=${lib.makeBinPath rotateDeps}" ];
        };
      };

      huix-virt-keyboard = {
        Unit = {
          Description = "The on-screen keyboard, shown by the bar button (wvkbd)";
          PartOf = [ "graphical-session.target" ];
          After = [ "graphical-session.target" ];
        };
        Service = {
          # Hidden until the bar button asks: the input-method --auto mode raised it for every
          # focused terminal the moment the mode began
          ExecStart = lib.concatStringsSep " " [
            (lib.getExe' pkgs.wvkbd "wvkbd-mobintl")
            "--hidden"
            "-L 300"
            "-H 320"
            # wvkbd reads one list on a portrait screen and another on a landscape one, which
            # a laptop panel is in any orientation but 90°; the keyboard key at the bottom
            # left steps through the list in order, so the numbers follow both alphabets,
            # and the emoji layer opens from the numbers
            "-l full,special,cyrillic,special"
            "--landscape-layers landscape,landscapespecial,cyrillic,landscapespecial"
            "--fn 'Doki 14'"
            "--bg ${bare.ink}"
            "--fg ${bare.jacket}"
            "--fg-sp ${bare.plum}"
            "--press ${bare.pink}"
            "--press-sp ${bare.pink}"
            "--text ${bare.paper}"
            "--text-sp ${bare.paper}"
          ];
          Restart = "on-failure";
        };
      };
    };
  };
}
