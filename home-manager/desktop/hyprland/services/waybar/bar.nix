{
  config,
  lib,
  criticalTemperature,
  palette,
  ...
}:

let
  cfg = config.rokokol.waybar;
  style = variant: import ./style.nix { inherit palette variant; };
in
{
  options.rokokol.waybar = {
    enable = lib.mkEnableOption "waybar";

    # By the device, not by /sys/class/hwmon/hwmonN: the kernel numbers the chips in the order
    # their drivers load, which changes from one boot to the next
    temperatureSensor = lib.mkOption {
      type = lib.types.nullOr (
        lib.types.submodule {
          options = {
            device = lib.mkOption {
              type = lib.types.str;
              example = "/sys/devices/pci0000:00/0000:00:18.3/hwmon";
              description = "hwmon directory of the chip's device, without the hwmonN under it";
            };
            input = lib.mkOption {
              type = lib.types.str;
              default = "temp1_input";
              description = "file of the sensor in the chip's hwmonN directory";
            };
          };
        }
      );
      default = null;
      description = "CPU sensor of the temperature module; null — waybar auto-selects";
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
          output = lib.optional (
            config.rokokol.hyprland.primaryMonitor != ""
          ) config.rokokol.hyprland.primaryMonitor;
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
          modules-center = [
            "hyprland/language"
            "clock"
          ];
          modules-right = [
            "group/hardware"
          ]
          ++ lib.optional cfg.nvidia "custom/gpu"
          ++ lib.optional cfg.backlight "backlight"
          ++ lib.optional cfg.shader "custom/shader"
          ++ [
            "pulseaudio"
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
            all-outputs = true;
            format = "{icon}";
            on-click = "activate";
            sort-by-number = true;
            format-icons = {
              "1" = "💖";
              "2" = "🧁";
              "3" = "🍵";
              "4" = "🎹";
              "5" = "🌸";
              "6" = "🍓";
              "7" = "🌙";
              "8" = "🫧";
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
            critical-threshold = criticalTemperature;
            format-critical = "{temperatureC}°C ⚠️";
          }
          // lib.optionalAttrs (cfg.temperatureSensor != null) {
            hwmon-path-abs = cfg.temperatureSensor.device;
            input-filename = cfg.temperatureSensor.input;
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

    # waybar follows the portal's colour scheme between the two variants; style.css is what it
    # reaches for when the portal does not answer, and there the bar stays dark
    xdg.configFile = {
      "waybar/style-light.css".text = style "light";
      "waybar/style-dark.css".text = style "dark";
      "waybar/style.css".text = style "dark";
    };
  };
}
