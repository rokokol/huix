{
  config,
  lib,
  palette,
  ...
}:

let
  cfg = config.rokokol.waybar;
  style = import ./style.nix { inherit palette; };
in
{
  options.rokokol.waybar = {
    enable = lib.mkEnableOption "waybar";

    temperatureHwmon = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "hwmon-path for the temperature module; null — waybar auto-selects";
    };

    # The on-screen keyboard is a keyboard too: its keymap is named "wvkbd", which the layout
    # module cannot resolve, so without a name it shows nothing from the moment wvkbd starts
    layoutKeyboard = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "keyboard whose layout the bar shows, as hyprctl devices names it; null — whichever keyboard reported a layout last";
    };
  };

  config = lib.mkIf cfg.enable {
    programs.waybar = {
      enable = true;
      systemd.enable = false;

      settings = {
        mainBar = {
          layer = "top";
          position = "top";
          height = 24;
          spacing = 2;

          mode = "dock";
          start_hidden = false;
          modifier-reset = "press";
          ipc = true;

          # The only place where module order is set: features declare only
          # their own settings, otherwise order would depend on the imports order
          modules-left = lib.optional (cfg.launcher || cfg.virtKeyboard) "group/buttons" ++ [
            "ext/workspaces"
            "hyprland/window"
          ];
          modules-center = [ "clock" ];
          modules-right = [
            "group/hardware"
          ]
          ++ lib.optional cfg.nvidia "custom/gpu"
          ++ lib.optional cfg.backlight "backlight"
          ++ lib.optional cfg.shader "custom/shader"
          ++ [
            "pulseaudio"
            "hyprland/language"
            "custom/notifications"
            "tray"
            "network"
          ]
          ++ lib.optional cfg.battery "battery";

          # The Wayland ext-workspace protocol rather than Hyprland's IPC, whose shape follows
          # the compositor's branch (see WORKAROUNDS.md). The special workspace comes marked
          # hidden and stays off the bar; an urgent one has no icon of its own here, the
          # urgent class in style.nix marks it
          "ext/workspaces" = {
            format = "{icon}";
            on-click = "activate";
            sort-by-number = true;
            format-icons = {
              "1" = "💖";
              "2" = "🧁";
              "3" = "🍵";
              "4" = "🎹";
              active = "✒️";
              default = "🤍";
            };
          };

          "hyprland/window" = {
            format = " {}";
            max-length = 30;
            separate-outputs = true;
          };

          "clock" = {
            format = "{:%H:%M} 📅";
            tooltip-format = "<tt><small>{calendar}</small></tt>";
            calendar = {
              mode = "month";
              on-scroll = 1;
              format = {
                today = "<span color='${palette.plum}'><b><u>{}</u></b></span>";
              };
            };
            "actions" = {
              on-scroll-up = "shift_up";
              on-scroll-down = "shift_down";
            };
          };

          "hyprland/language" = {
            format = "{}";
            format-en = "🏳‍🌈";
            format-ru = "ZOV";
          }
          // lib.optionalAttrs (cfg.layoutKeyboard != null) { keyboard-name = cfg.layoutKeyboard; };

          "group/hardware" = {
            orientation = "horizontal";
            modules = [
              "cpu"
              (if cfg.swap then "custom/memory" else "memory")
              "temperature"
            ];
          };

          # One chip under both buttons, so they read as buttons and not as the desktop
          "group/buttons" = {
            orientation = "horizontal";
            modules =
              lib.optional cfg.launcher "custom/launcher" ++ lib.optional cfg.virtKeyboard "custom/virt-keyboard";
          };

          "cpu" = {
            format = "{usage}% 💻";
            interval = 2;
          };

          "temperature" = {
            format = "{temperatureC}°C 🌡️";
            critical-threshold = 80;
            format-critical = "{temperatureC}°C ⚠️";
          }
          // lib.optionalAttrs (cfg.temperatureHwmon != null) {
            hwmon-path = cfg.temperatureHwmon;
          };

          "memory" = {
            format = "{used:0.1f}Gb 🧠";
            interval = 2;
          };

          "tray" = {
            icon-size = 14;
            spacing = 5;
          };

          "network" = {
            format-wifi = "📶";
            format-ethernet = "🌐";
            tooltip-format = "{essid}";
          };

          "pulseaudio" = {
            format = "{volume}% {icon}";
            format-muted = "{volume}% 🔇";
            format-icons = {
              default = [
                "🔈"
                "🔉"
                "🔊"
              ];
            };
            on-click = "pavucontrol";
          };
        };
      };
    };

    # The bar keeps one dark sheet under either colour scheme — style.css is what
    # waybar reaches for when no style-light/style-dark sits beside it
    xdg.configFile."waybar/style.css".text = style;
  };
}
