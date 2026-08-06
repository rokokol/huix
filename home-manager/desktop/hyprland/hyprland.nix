{
  config,
  lib,
  osConfig,
  ...
}:

let
  cfg = config.custom.hyprland;
in
{
  imports = [
    ./services/wallpaper-collager.nix
    ./services/hyprland-packages.nix
    ./services/hyprlock.nix
    ./services/lid-mode.nix
    ./services/wl-clip-persist.nix
    ./services/waybar
  ];

  options.custom.hyprland = {
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

      settings = {
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
