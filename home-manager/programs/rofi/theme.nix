# One rofi layout, two colour sets. Light and dark differed only in their hexes, so the
# structure lived twice; now it lives here and each set is a list of ddlc-palette keys
{ palette }:

let
  # The same half-step offset grid the site's tile uses, as one SVG instead of 30 hand-placed circles
  polkaSvg =
    {
      ground,
      dot,
      w ? 720,
      h ? 520,
      step ? 140,
      row ? 90,
      r ? 19,
    }:
    let
      rows = builtins.genList (
        y:
        let
          cy = 38 + y * row;
          shift = if (builtins.bitAnd y 1) == 1 then step / 2 else 0;
          cols = builtins.genList (
            x: ''    <circle cx="${toString (55 + shift + x * step)}" cy="${toString cy}" r="${toString r}" />''
          ) (w / step + 1);
        in
        builtins.concatStringsSep "\n" cols
      ) (h / row + 1);
    in
    ''
      <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${toString w} ${toString h}" preserveAspectRatio="xMidYMid slice">
        <rect width="${toString w}" height="${toString h}" fill="${ground}" />

        <g fill="${dot}">
      ${builtins.concatStringsSep "\n" rows}
        </g>
      </svg>
    '';

  # Every colour below is a palette key, so a set reads as a list of names
  rasi =
    {
      polka,
      ground,
      panel,
      panelAlpha,
      text,
      placeholderAlpha,
      accent,
      edge,
      edgeAlpha,
      rowEdge,
      rowEdgeAlpha,
      selBg,
      selBgAlpha,
      selEdge,
      selFg,
      alt,
      altAlpha,
      msg,
      msgAlpha,
    }:
    let
      hex = n: palette.${n};
      rgba = n: palette.rgba.${n};
    in
    ''
      * {
        background-color: transparent;
        text-color: ${hex text};
        margin: 0px;
        padding: 0px;
        font: "Doki 12";
      }

      window {
        location: center;
        width: 720px;
        border: 2px;
        border-color: ${rgba edge edgeAlpha};
        border-radius: 28px;
        dynamic: true;
        padding: 18px;
        background-color: ${hex ground};
        background-image: url("../assets/${polka}", both);
      }

      inputbar {
        background-color: ${rgba panel panelAlpha};
        border: 1px;
        border-color: ${rgba edge "0.5"};
        margin: 6px 6px 14px 6px;
        padding: 14px 16px;
        border-radius: 18px;
        children: [ prompt, entry ];
      }

      prompt {
        text-color: ${hex accent};
        margin: 0px 12px 0px 0px;
        font: "Doki 13";
      }

      entry {
        placeholder: "Okay, everyone!";
        placeholder-color: ${rgba text placeholderAlpha};
        text-color: ${hex text};
      }

      listview {
        background-color: ${rgba panel "0.45"};
        margin: 0px 6px 6px 6px;
        padding: 6px;
        border-radius: 20px;
        columns: 1;
        lines: 6;
        spacing: 8px;
        fixed-height: false;
      }

      element {
        orientation: horizontal;
        padding: 10px 14px;
        spacing: 10px;
        border-radius: 18px;
        border: 1px;
        border-color: ${rgba rowEdge rowEdgeAlpha};
        background-color: ${rgba panel "0.93"};
      }

      element-icon {
        background-color: ${rgba accent "0.09"};
        padding: 6px;
        size: 28px;
        horizontal-align: 0.5;
        vertical-align: 0.5;
        border-radius: 12px;
      }

      element-text {
        horizontal-align: 0;
        vertical-align: 0.5;
        text-color: ${hex text};
        font: "DepartureMono Nerd Font Mono 12";
      }

      element selected {
        background-color: ${rgba selBg selBgAlpha};
        border-color: ${hex selEdge};
        text-color: ${hex selFg};
      }

      element selected element-text {
        text-color: ${hex selFg};
      }

      element selected element-icon {
        background-color: ${rgba selFg "0.16"};
      }

      element alternate {
        background-color: ${rgba alt altAlpha};
      }

      message {
        margin: 8px 10px 0px 10px;
        padding: 10px 14px;
        background-color: ${rgba msg msgAlpha};
        border: 1px;
        border-color: ${rgba edge "0.4"};
        border-radius: 16px;
      }

      textbox {
        text-color: ${hex accent};
        font: "DepartureMono Nerd Font Mono 12";
      }
    '';
in
{
  polkaLight = polkaSvg {
    ground = palette.paper;
    dot = palette.dot;
  };

  polkaDark = polkaSvg {
    ground = palette.yuriShadow;
    dot = palette.yuri;
  };

  light = rasi {
    polka = "polka-light.svg";
    ground = "paper";
    panel = "paper";
    panelAlpha = "0.92";
    text = "ink";
    placeholderAlpha = "0.52";
    accent = "plum";
    edge = "pink";
    edgeAlpha = "0.96";
    rowEdge = "blush";
    rowEdgeAlpha = "0.94";
    # Same wash as in dark, only lighter — and white text would drown in it,
    # so the selected row keeps the body text colour
    selBg = "pink";
    selBgAlpha = "0.45";
    selEdge = "plum";
    selFg = "ink";
    alt = "dot";
    altAlpha = "0.55";
    msg = "dot";
    msgAlpha = "0.77";
  };

  dark = rasi {
    polka = "polka-dark.svg";
    ground = "yuriShadow";
    panel = "yuri";
    panelAlpha = "0.92";
    text = "dot";
    placeholderAlpha = "0.48";
    accent = "pink";
    edge = "pink";
    edgeAlpha = "0.72";
    rowEdge = "plum";
    rowEdgeAlpha = "0.55";
    # The only opaque surface in the theme would read as a sticker on the dark ground,
    # and the pink edge would vanish into it. Translucent it sits in the same material
    selBg = "plum";
    selBgAlpha = "0.55";
    selEdge = "pink";
    selFg = "dot";
    alt = "yuri";
    altAlpha = "0.96";
    msg = "yuri";
    msgAlpha = "0.77";
  };
}
