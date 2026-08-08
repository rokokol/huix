{
  config,
  lib,
  palette,
  ...
}:

let
  cfg = config.custom.waybar;
in
{
  options.custom.waybar = {
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

      # The style is shared; selectors for disabled modules simply don't match
      style = ''
        * {
            border: none;
            font-family: "Doki";
            font-size: 12px;
            min-height: 0;
        }

        window#waybar {
            background: transparent;
        }

        /* Modules style (islands) */
        #workspaces, #window, #clock, #pulseaudio, #network, #language, #custom-gpu, #custom-shader, #custom-notifications, #hardware, #backlight, #battery, #tray {
            background: ${palette.rgba palette.paper "0.9"};
            color: ${palette.inkSoft};
            padding: 0px 8px;
            margin: 2px 1px;
            border-radius: 12px;
            border: 1px solid ${palette.dot};
        }

        /* Remove borders/backgrounds from modules inside the hardware group so they blend */
        #cpu, #memory, #temperature {
            background: transparent;
            border: none;
            margin: 0;
            padding: 0 4px;
            color: ${palette.inkSoft};
        }

        #clock {
            color: ${palette.plum};
            padding: 0 12px;
        }

        /* "Do not disturb" mode — the island dims to gray */
        #custom-notifications.dnd {
            background: ${palette.rgba palette.ash "0.9"};
            border: 1px solid ${palette.muted};
            color: ${palette.muted};
        }

        #window {
            background: transparent;
            color: ${palette.textOnDark};
            border: none;
            box-shadow: none;

            text-shadow:
                -1px -1px 0 ${palette.ink},
                 1px -1px 0 ${palette.ink},
                -1px  1px 0 ${palette.ink},
                 1px  1px 0 ${palette.ink};
        }

        #workspaces button {
            padding: 0 2px;
            color: ${palette.blush};
        }

        #workspaces button.active {
            color: ${palette.plum};
            background: ${palette.paper};
            border-radius: 10px;
            min-width: 20px;
        }

        #workspaces button.urgent {
            color: ${palette.bow};
            animation-name: glitch-text;
            animation-duration: 0.3s;
            animation-iteration-count: infinite;
            animation-direction: alternate;
        }

        @keyframes glitch-text {
            0% {
                text-shadow: 2px 0 0 ${palette.splitCyan};
            }
            50% {
                text-shadow: -2px 0 0 ${palette.splitMagenta};
            }
            100% {
                text-shadow: 2px 0 0 ${palette.splitCyan};
            }
        }
      '';
    };
  };
}
