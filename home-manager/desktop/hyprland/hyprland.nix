{
  config,
  lib,
  osConfig,
  palette,
  ...
}:

let
  cfg = config.rokokol.hyprland;
  inherit (palette) bare;
in
{
  imports = [
    ./services/wallpaper-collager.nix
    ./services/hyprland-packages.nix
    ./services/hyprlock.nix
    ./services/lid-mode.nix
    ./services/rofi-wooordhunt.nix
    ./services/screen-shader.nix
    ./services/wl-clip-persist.nix
    ./services/waybar
  ];

  options.rokokol.hyprland = {
    enable = lib.mkEnableOption "Hyprland";

    monitorScale = lib.mkOption {
      type = lib.types.str;
      default = "1";
      description = "monitor scale (,preferred,auto,<scale>)";
    };

    kbOptions = lib.mkOption {
      type = lib.types.str;
      default = osConfig.services.xserver.xkb.options;
      description = "XKB options; defaults to the system services.xserver.xkb.options";
    };

    touchpadNaturalScroll = lib.mkEnableOption "touchpad natural scroll";

    wallpaperImage = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "static wallpaper via awww; null — none (see wallpaperCollage)";
    };

    startupArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "applications to autostart";
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "hyprlang";

      # HM's session target would stop uwsm's compositor unit mid-login; Hyprland exports the vars itself (see workarounds.md)
      systemd.enable = false;

      settings = {
        # Emitted before hyprland.conf is sourced, so the file can stay colour-free
        general = {
          "col.active_border" = "rgba(${bare.pink}ee) rgba(${bare.plum}ee) 45deg";
          "col.inactive_border" = "rgba(${bare.jacket}aa)";
        };

        decoration.shadow.color = "rgba(${bare.ink}ee)";

        monitor = [
          ",preferred,auto,${cfg.monitorScale}"
        ];

        input = {
          kb_layout = osConfig.services.xserver.xkb.layout;
          kb_variant = osConfig.services.xserver.xkb.variant;
          kb_options = cfg.kbOptions;

          follow_mouse = 1;

          sensitivity = 0; # -1.0 — 1.0, 0 — unchanged
        }
        // lib.optionalAttrs cfg.touchpadNaturalScroll {
          touchpad = {
            natural_scroll = true;
          };
        };

        exec-once = cfg.startupArgs ++ lib.optionals (cfg.wallpaperImage != null) [
          "awww init"
          "awww img ${cfg.wallpaperImage}"
        ];
      };
    };
  };
}
