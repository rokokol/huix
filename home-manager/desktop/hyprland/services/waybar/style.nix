# One waybar sheet, two colour sets. waybar picks style-light.css or style-dark.css by
# the portal's org.freedesktop.appearance and swaps them live on change — so the layout
# lives here once and only the colours are written twice
{ palette }:

let
  css =
    {
      panel,
      panelAlpha,
      edge,
      edgeAlpha,
      edgeWidth,
      shadow,
      shadowAlpha,
      text,
      secondary,
      accent,
      inset,
      insetAlpha,
      wsHover,
      wsHoverAlpha,
      wsActiveBg,
      wsActiveAlpha,
      wsActiveFg,
      dnd,
      dndAlpha,
      warn,
      crit,
    }:
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
          background: ${palette.rgba panel panelAlpha};
          color: ${text};
          padding: 0 4px;
          margin: 2px 6px;
          border-radius: 13px;
          border: ${edgeWidth} solid ${palette.rgba edge edgeAlpha};
          box-shadow: 0 2px 6px ${palette.rgba shadow shadowAlpha};
      }

      /* Modules ride on the panel and carry no ground of their own */
      #window, #clock, #cpu, #memory, #temperature, #pulseaudio, #network, #language,
      #custom-gpu, #custom-shader, #custom-notifications, #backlight, #battery {
          background: transparent;
          border: none;
          margin: 0;
          padding: 0 5px;
          color: ${text};
      }

      /* Machine stats and the tray read as blocks inside the right panel */
      #hardware, #tray {
          background: ${palette.rgba inset insetAlpha};
          border: none;
          border-radius: 10px;
          margin: 3px 2px;
          padding: 0 3px;
      }

      #clock {
          color: ${accent};
          font-weight: bold;
          padding: 0 8px;
      }

      /* Secondary next to the workspaces it follows */
      #window {
          color: ${secondary};
      }

      /* "Do not disturb" mode — the indicator dims to gray */
      #custom-notifications.dnd {
          background: ${palette.rgba palette.ash dndAlpha};
          border-radius: 9px;
          color: ${dnd};
      }

      #temperature.critical, #battery.critical {
          color: ${crit};
      }

      #battery.warning {
          color: ${warn};
      }

      #workspaces button {
          padding: 0 3px;
          border-radius: 9px;
          color: ${text};
      }

      #workspaces button:hover {
          background: ${palette.rgba wsHover wsHoverAlpha};
      }

      #workspaces button.active {
          color: ${wsActiveFg};
          background: ${palette.rgba wsActiveBg wsActiveAlpha};
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
in
{
  # Same glass, lighter tone — but thicker than the dark set on purpose: a pale ground
  # takes the wallpaper in, so thinned much further it greys out over dark wallpaper
  light = css {
    panel = palette.dot;
    panelAlpha = "0.72";
    edge = palette.pink;
    edgeAlpha = "0.7";
    edgeWidth = "1px";
    shadow = palette.bowShadow;
    shadowAlpha = "0.22";
    text = palette.ink;
    secondary = palette.mutedPink;
    accent = palette.yuri;
    inset = palette.paper;
    insetAlpha = "0.75";
    wsHover = palette.pink;
    wsHoverAlpha = "0.22";
    wsActiveBg = palette.pink;
    wsActiveAlpha = "0.45";
    wsActiveFg = palette.ink;
    dnd = palette.mutedPink;
    dndAlpha = "0.55";
    warn = palette.warnFg;
    crit = palette.critFg;
  };

  # The dark ground takes more glass, and it needs the loud urgency shades — the
  # dark-on-light ones sink into it
  dark = css {
    panel = palette.paperDark;
    panelAlpha = "0.62";
    edge = palette.pink;
    edgeAlpha = "0.55";
    edgeWidth = "1px";
    shadow = palette.ink;
    shadowAlpha = "0.35";
    text = palette.textOnDark;
    secondary = palette.mutedDark;
    accent = palette.blush;
    inset = palette.paper;
    insetAlpha = "0.07";
    wsHover = palette.pink;
    wsHoverAlpha = "0.25";
    wsActiveBg = palette.plum;
    wsActiveAlpha = "0.55";
    wsActiveFg = palette.dot;
    dnd = palette.mutedDark;
    dndAlpha = "0.18";
    warn = palette.sayori;
    crit = palette.bow;
  };
}
