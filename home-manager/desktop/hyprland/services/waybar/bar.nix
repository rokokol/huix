{
  config,
  lib,
  palette,
  ...
}:

let
  cfg = config.rokokol.waybar;
  styles = import ./style.nix { inherit palette; };
in
{
  options.rokokol.waybar = {
    enable = lib.mkEnableOption "waybar";

    temperatureHwmon = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "hwmon-path for the temperature module; null — waybar auto-selects";
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

          modules-left = [
            "hyprland/workspaces"
            "hyprland/window"
          ];
          modules-center = [ "clock" ];
          # The only place where module order is set: features declare only
          # their own settings, otherwise order would depend on the imports order
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

          "hyprland/workspaces" = {
            format = "{icon}";
            on-click = "activate";
            format-icons = {
              "1" = "💖";
              "2" = "🧁";
              "3" = "🍵";
              "4" = "🎹";
              urgent = "⚠️";
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
          };

          "group/hardware" = {
            orientation = "horizontal";
            modules = [
              "cpu"
              "memory"
              "temperature"
            ];
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

    # waybar picks the sheet by the portal's appearance and reloads it live when
    # toggle-theme.sh flips color-scheme — so it must not be started with -s, and
    # style.css stays as the fallback for a session without a portal
    xdg.configFile = {
      "waybar/style-light.css".text = styles.light;
      "waybar/style-dark.css".text = styles.dark;
      "waybar/style.css".text = styles.dark;
    };
  };
}
