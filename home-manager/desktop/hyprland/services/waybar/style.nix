# The one waybar sheet — a single dark set. waybar picks style-light.css / style-dark.css by the
# portal's org.freedesktop.appearance and falls back to style.css when neither sits next to it, so
# laying down only style.css keeps the bar dark under either colour scheme
{ palette }:

''
  * {
      border: none;
      font-family: "Doki";
      font-size: 12px;
      min-height: 0;
  }

  window#waybar {
      background: transparent;
  }

  /* Three panels — left / center / right — instead of an island per module.
     The waybar layer is blurred in hyprland.conf, so a translucent panel frosts */
  .modules-left, .modules-center, .modules-right {
      background: ${palette.rgba palette.paperDark "0.62"};
      color: ${palette.textOnDark};
      padding: 0 4px;
      margin: 2px 6px;
      border-radius: 13px;
      border: 1px solid ${palette.rgba palette.pink "0.55"};
      box-shadow: 0 2px 6px ${palette.rgba palette.ink "0.35"};
  }

  /* Modules ride on the panel and carry no ground of their own */
  #window, #clock, #cpu, #memory, #temperature, #pulseaudio, #network, #language,
  #custom-gpu, #custom-shader, #custom-notifications, #backlight, #battery {
      background: transparent;
      border: none;
      margin: 0;
      padding: 0 5px;
      color: ${palette.textOnDark};
  }

  /* Machine stats read as a block inside the right panel */
  #hardware, #tray {
      background: ${palette.rgba palette.paper "0.07"};
      border: none;
      border-radius: 10px;
      margin: 3px 2px;
      padding: 0 3px;
  }

  #clock {
      color: ${palette.blush};
      font-weight: bold;
      padding: 0 8px;
  }

  /* Secondary next to the workspaces it follows */
  #window {
      color: ${palette.mutedDark};
  }

  /* "Do not disturb" mode — the indicator dims into a chip */
  #custom-notifications.dnd {
      background: ${palette.rgba palette.ash "0.18"};
      border-radius: 9px;
      color: ${palette.mutedDark};
  }

  #temperature.critical, #battery.critical {
      color: ${palette.bow};
  }

  #battery.warning {
      color: ${palette.sayori};
  }

  #workspaces button {
      padding: 0 3px;
      border-radius: 9px;
      color: ${palette.textOnDark};
  }

  #workspaces button:hover {
      background: ${palette.rgba palette.pink "0.25"};
  }

  #workspaces button.active {
      color: ${palette.dot};
      background: ${palette.rgba palette.plum "0.55"};
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
''
