{
  config,
  lib,
  pkgs,
  huixDir,
  palette,
  ...
}:

# The mode itself is two user units and the switch binds; what happens on the way in and
# out is tablet-mode.sh, which is also what the waybar keyboard button calls
let
  cfg = config.rokokol.hyprland;
  scriptsDir = "${huixDir}/scripts";
  inherit (palette) bare;
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

    # settings are applied before the shared config is sourced, so $mainMod is not defined
    # yet and the modifier is written literally
    wayland.windowManager.hyprland.settings = {
      bind = [
        "SUPER, M, exec, ${scriptsDir}/rotate-screen.sh next"
        "SUPER SHIFT, M, exec, ${scriptsDir}/tablet-mode.sh toggle"
      ];
      # bindl fires with the screen locked too. The switch reports changes only, and a
      # reload resets the transform and the titlebars, so sync runs from exec on every reload
      bindl = [
        ", switch:on:${cfg.tabletModeSwitch}, exec, ${scriptsDir}/tablet-mode.sh on"
        ", switch:off:${cfg.tabletModeSwitch}, exec, ${scriptsDir}/tablet-mode.sh off"
      ];
      exec = [ "${scriptsDir}/tablet-mode.sh sync" ];
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

      huix-osk = {
        Unit = {
          Description = "The on-screen keyboard, shown by a text field or the bar button (wvkbd)";
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
            "-l full,special,cyrillic,emoji"
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
