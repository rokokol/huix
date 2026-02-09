{ ... }:
{
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
          "custom/menu"
          "hyprland/workspaces"
          "hyprland/window"
        ];
        modules-center = [ "clock" ];
        modules-right = [
          "cpu"
          "memory"
          "temperature"
          "backlight"
          "pulseaudio"
          "hyprland/language"
          "network"
          "battery"
        ];

        "custom/menu" = {
          format = " 🎀 ";
          on-click = "rofi -show drun";
          tooltip = false;
        };

        "hyprland/workspaces" = {
          format = "{icon}";
          on-click = "activate";
          format-icons = {
            "1" = "💖";
            "2" = "🧁";
            "3" = "🍵";
            "4" = "🎹";
            urgent = "🩸";
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
              today = "<span color='#f11a7e'><b><u>{}</u></b></span>";
            };
          };
          "actions" = {
            on-scroll-up = "shift_up";
            on-scroll-down = "shift_down";
          };
        };

        "backlight" = {
          device = "intel_backlight";
          format = "{percent}% {icon}";
          format-icons = [
            "🌑"
            "🌘"
            "🌗"
            "🌖"
            "🌕"
          ];
          on-scroll-up = "brightnessctl set 1%+";
          on-scroll-down = "brightnessctl set 1%-";
        };
        "hyprland/language" = {
          format = "{}";
          format-en = "🏳‍🌈";
          format-ru = "ZOV";
        };
        "cpu" = {
          format = "{usage}% 💻";
          interval = 2;
        };
        "temperature" = {
          # thermal-zone = 2;
          # hwmon-path = "/sys/class/hwmon/hwmon2/temp1_input";
          format = "{temperatureC}°C 🌡️";
          critical-threshold = 80;
          format-critical = "{temperatureC}°C ⚠️";
        };
        "memory" = {
          format = "{used:0.1f}G 🧠";
          interval = 2;
        };
        "battery" = {
          format = "{capacity}% {icon}";
          format-icons = [ "🔋" ];
        };
        "network" = {
          format-wifi = "📶";
          format-ethernet = "🌐";
          tooltip-format = "{essid}";
        };
        "pulseaudio" = {
          format = "{volume}% {icon}";
          format-icons = {
            default = [ "🔊" ];
          };
          on-click = "pavucontrol";
        };
      };
    };

    style = ''
      /* transition: all 0.5s ease-in-out; to animation */
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
      #custom-menu, #workspaces, #window, #clock, #cpu, #memory, #pulseaudio, #temperature, #network, #battery, #language, #backlight {
          background: rgba(255, 240, 245, 0.9);
          color: #4c4c4c;
          padding: 0px 8px;   
          margin: 2px 1px;    
          border-radius: 12px;
          border: 1px solid #ff70a6;
      }

      #clock {
          color: #f11a7e;
          padding: 0 12px;
      }

      #window {
          background: transparent;
          color: #fceaf1; 
          border: none;
          box-shadow: none;
          
          text-shadow: 
              -1px -1px 0 #000000, 
               1px -1px 0 #000000, 
              -1px  1px 0 #000000, 
               1px  1px 0 #000000;
      }

      #workspaces button {
          padding: 0 2px;
          color: #ffbde1;
      }

      #workspaces button.active {
          color: #f11a7e;
          background: white;
          border-radius: 10px;
          min-width: 20px;
      }

      #workspaces button.urgent {
          color: #ff0000;
          animation-name: glitch-text;
          animation-duration: 0.3s;
          animation-iteration-count: infinite;
          animation-direction: alternate;
      }

      @keyframes glitch-text {
          0% {
              text-shadow: 2px 0 0 #00ffff;
          }
          50% {
              text-shadow: -2px 0 0 #ff00ff;
          }
          100% {
              text-shadow: 2px 0 0 #00ffff;
          }
      }
    '';
  };
}
