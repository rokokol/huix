# The waybar sheet for one variant. waybar picks style-light.css / style-dark.css by the portal's
# org.freedesktop.appearance and reloads when it changes, so bar.nix lays down both and the bar
# follows toggle-theme.sh with nothing of its own to swap. The rules are shared; a variant differs
# only in the roles below. The panels are opaque: a see-through ground lets the wallpaper decide
# the contrast of the text on it
{ palette, variant }:

let
  roles = {
    dark = {
      panel = palette.yuriShadow;
      text = palette.dot;
      border = palette.rgba.pink "0.55";
      shadow = palette.rgba.ink "0.35";
      chip = palette.rgba.paper "0.08";
      tray = palette.rgba.paper "0.08";
      clock = palette.blush;
      secondary = palette.jacket;
      dndGround = palette.rgba.ash "0.18";
      dndText = palette.jacket;
      critical = palette.bow;
      warning = palette.sayori;
      hover = palette.rgba.pink "0.25";
      activeText = palette.paper;
      activeGround = palette.rgba.plum "0.8";
      urgent = palette.bow;
    };
    # Pastel ground, dark ink: the warm pastels fall under 3:1 on paper, so they stay in the
    # ground and the frame, and the text takes yuriShadow, yuri and plum
    light = {
      panel = palette.dot;
      text = palette.yuriShadow;
      border = palette.rgba.pink "0.7";
      shadow = palette.rgba.plum "0.25";
      chip = palette.rgba.paper "0.6";
      # Tray icons are the apps' own pixmaps, some always white, so the tray gets a mid ground
      # that both white and dark icons read on
      tray = palette.rgba.jacket "0.6";
      clock = palette.plum;
      secondary = palette.yuri;
      dndGround = palette.rgba.jacket "0.3";
      dndText = palette.yuri;
      critical = palette.bow;
      warning = palette.bowShadow;
      hover = palette.rgba.blush "0.9";
      activeText = palette.paper;
      activeGround = palette.rgba.plum "0.9";
      urgent = palette.bow;
    };
  };
  c = roles.${variant};
in
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

  /* Three panels — left / center / right — instead of an island per module */
  .modules-left, .modules-center, .modules-right {
      background: ${c.panel};
      color: ${c.text};
      padding: 0 4px;
      margin: 2px 6px;
      border-radius: 13px;
      border: 1px solid ${c.border};
      box-shadow: 0 2px 6px ${c.shadow};
  }

  /* Modules ride on the panel and carry no ground of their own */
  #window, #clock, #cpu, #memory, #custom-memory, #temperature, #pulseaudio, #network,
  #language, #custom-gpu, #custom-shader, #custom-notifications, #custom-launcher,
  #custom-virt-keyboard, #backlight, #battery {
      background: transparent;
      border: none;
      margin: 0;
      padding: 0 5px;
      color: ${c.text};
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
  #hardware, #buttons, #language {
      background: ${c.chip};
  }

  #tray {
      background: ${c.tray};
  }

  /* A group's modules pad themselves, so the chip adds only 3px */
  #hardware, #tray, #buttons {
      padding: 0 3px;
  }

  #clock {
      color: ${c.clock};
      font-weight: bold;
      padding: 0 8px;
  }

  /* A lone module in a chip: its own 5px plus the chip's 3px, as the hardware stats get */
  #language {
      padding: 0 8px;
  }

  /* Secondary next to the workspaces it follows */
  #window {
      color: ${c.secondary};
  }

  /* "Do not disturb" mode — the indicator dims into a chip */
  #custom-notifications.dnd {
      background: ${c.dndGround};
      color: ${c.dndText};
  }

  #temperature.critical, #battery.critical {
      color: ${c.critical};
  }

  #battery.warning {
      color: ${c.warning};
  }

  #workspaces button {
      padding: 0 3px;
      color: ${c.text};
  }

  #workspaces button:hover {
      background: ${c.hover};
  }

  /* The one filled chip on the bar */
  #workspaces button.active {
      color: ${c.activeText};
      background: ${c.activeGround};
  }

  #workspaces button.urgent {
      color: ${c.urgent};
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
