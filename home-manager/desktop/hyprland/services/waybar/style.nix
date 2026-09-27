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
     The waybar layer is blurred in hyprland.lua, so a translucent panel frosts */
  .modules-left, .modules-center, .modules-right {
      background: ${palette.rgba.yuriShadow "0.62"};
      color: ${palette.dot};
      padding: 0 4px;
      margin: 2px 6px;
      border-radius: 13px;
      border: 1px solid ${palette.rgba.pink "0.55"};
      box-shadow: 0 2px 6px ${palette.rgba.ink "0.35"};
  }

  /* Modules ride on the panel and carry no ground of their own */
  #window, #clock, #cpu, #memory, #custom-memory, #temperature, #pulseaudio, #network,
  #language, #custom-gpu, #custom-shader, #custom-notifications, #custom-launcher,
  #custom-virt-keyboard, #backlight, #battery {
      background: transparent;
      border: none;
      margin: 0;
      padding: 0 5px;
      color: ${palette.dot};
  }

  /* The one chip shape on the bar; the rules below give each chip only its colour.
     The shape holds in every state, so a chip that lights up never moves its neighbours */
  #hardware, #tray, #buttons, #language, #custom-notifications, #workspaces button {
      border-radius: 10px;
      margin: 3px 2px;
  }

  /* Machine stats read as a block inside the right panel; the button group on the left
     gets the same chip, so a finger sees where to press, and the layout gets it to stand
     apart from the clock beside it */
  #hardware, #tray, #buttons, #language {
      background: ${palette.rgba.paper "0.07"};
  }

  /* A group's modules pad themselves, so the chip adds only 3px */
  #hardware, #tray, #buttons {
      padding: 0 3px;
  }

  #clock {
      color: ${palette.blush};
      font-weight: bold;
      padding: 0 8px;
  }

  /* A lone module in a chip: its own 5px plus the chip's 3px, as the hardware stats get */
  #language {
      padding: 0 8px;
  }

  /* Secondary next to the workspaces it follows */
  #window {
      color: ${palette.jacket};
  }

  /* "Do not disturb" mode — the indicator dims into a chip */
  #custom-notifications.dnd {
      background: ${palette.rgba.ash "0.18"};
      color: ${palette.jacket};
  }

  #temperature.critical, #battery.critical {
      color: ${palette.bow};
  }

  #battery.warning {
      color: ${palette.sayori};
  }

  #workspaces button {
      padding: 0 3px;
      color: ${palette.dot};
  }

  #workspaces button:hover {
      background: ${palette.rgba.pink "0.25"};
  }

  /* The one thing on the bar brighter than the body text */
  #workspaces button.active {
      color: ${palette.paper};
      background: ${palette.rgba.plum "0.55"};
  }

  #workspaces button.urgent {
      color: ${palette.bow};
      animation-name: glitch-text;
      animation-duration: 0.3s;
      animation-iteration-count: infinite;
      animation-direction: alternate;
  }

  /* RGB-split, the same pair the greeter uses */
  @keyframes glitch-text {
      0% {
          text-shadow: 2px 0 0 ${palette.sayoriEye};
      }
      50% {
          text-shadow: -2px 0 0 ${palette.bow};
      }
      100% {
          text-shadow: 2px 0 0 ${palette.sayoriEye};
      }
  }
''
