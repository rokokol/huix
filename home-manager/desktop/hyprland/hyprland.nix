{
  config,
  lib,
  osConfig,
  huixDir,
  palette,
  ...
}:

let
  cfg = config.rokokol.hyprland;
  inherit (palette) bare;
  inherit (lib.generators) mkLuaInline;
  toLua = lib.generators.toLua { };
in
{
  imports = [
    ./services/wallpaper-collager.nix
    ./services/hyprland-packages.nix
    ./services/hyprlock.nix
    ./services/lid-mode.nix
    ./services/rofi-wooordhunt.nix
    ./services/screen-shader.nix
    ./services/tablet-mode.nix
    ./services/titlebars.nix
    ./services/touch-gestures.nix
    ./services/wl-clip-persist.nix
    ./services/waybar
  ];

  options.rokokol.hyprland = {
    enable = lib.mkEnableOption "Hyprland";

    monitorScale = lib.mkOption {
      type = lib.types.float;
      default = 1.0;
      description = "the scale of every monitor no rule names";
    };

    kbOptions = lib.mkOption {
      type = lib.types.str;
      default = osConfig.services.xserver.xkb.options;
      description = "XKB options; defaults to the system services.xserver.xkb.options";
    };

    touchpadNaturalScroll = lib.mkEnableOption "touchpad natural scroll";

    menuCommand = lib.mkOption {
      type = lib.types.str;
      default = "rofi -show drun -show-icons -calc-command \"echo -n '{result}' | wl-copy\"";
      description = "the application menu, as HUIX.menu in the Hyprland config and wherever else a button opens it";
    };

    wallpaperImage = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "static wallpaper via awww; null — none (see wallpaperCollage)";
    };
  };

  config = lib.mkIf cfg.enable {
    wayland.windowManager.hyprland = {
      enable = true;
      configType = "lua";

      # HM's session target would stop uwsm's compositor unit mid-login; Hyprland exports the
      # vars itself (see WORKAROUNDS.md)
      systemd.enable = false;

      # Every attribute here is one hl.<name>(...) call in the generated hyprland.lua, which
      # runs before hyprland.lua of this directory is loaded below, so that file stays
      # colour-free and host-free
      settings = {
        config = {
          general = {
            active_border = "rgba(${bare.pink}ee) rgba(${bare.plum}ee) 45deg";
            inactive_border = "rgba(${bare.jacket}aa)";
          };

          decoration.shadow.color = "rgba(${bare.ink}ee)";

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
        };

        # The rule with no output is the fallback for every monitor
        monitor = {
          output = "";
          mode = "preferred";
          position = "auto";
          scale = cfg.monitorScale;
        };

        on = lib.optional (cfg.wallpaperImage != null) {
          _args = [
            "hyprland.start"
            (mkLuaInline ''
              function()
                hl.exec_cmd("awww init")
                hl.exec_cmd(${toLua "awww img ${cfg.wallpaperImage}"})
              end'')
          ];
        };
      };

      # The shared config lives in the checkout and is read live, like the scripts, so an
      # edit needs no rebuild. What it takes from Nix comes through one global table
      extraConfig = ''
        HUIX = {
          menu = ${toLua cfg.menuCommand},
          scripts = ${toLua "${huixDir}/scripts"},
        }
        dofile(${toLua "${huixDir}/home-manager/desktop/hyprland/hyprland.lua"})
      '';
    };
  };
}
