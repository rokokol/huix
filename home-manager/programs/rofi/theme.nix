# One rofi layout, two colour sets. Light and dark differed only in their hexes, so the
# structure lived twice; now it lives here and the colours come from theme/palette.nix
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
      selEdge,
      selFg,
      alt,
      altAlpha,
      msg,
      msgAlpha,
    }:
    ''
      * {
        background-color: transparent;
        text-color: ${text};
        margin: 0px;
        padding: 0px;
        font: "Doki 12";
      }

      window {
        location: center;
        width: 720px;
        border: 2px;
        border-color: ${palette.rgba edge edgeAlpha};
        border-radius: 28px;
        dynamic: true;
        padding: 18px;
        background-color: ${ground};
        background-image: url("../assets/${polka}", both);
      }

      inputbar {
        background-color: ${palette.rgba panel panelAlpha};
        border: 1px;
        border-color: ${palette.rgba edge "0.5"};
        margin: 6px 6px 14px 6px;
        padding: 14px 16px;
        border-radius: 18px;
        children: [ prompt, entry ];
      }

      prompt {
        text-color: ${accent};
        margin: 0px 12px 0px 0px;
        font: "Doki 13";
      }

      entry {
        placeholder: "Okay, everyone!";
        placeholder-color: ${palette.rgba text placeholderAlpha};
        text-color: ${text};
      }

      listview {
        background-color: ${palette.rgba panel "0.45"};
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
        border-color: ${palette.rgba rowEdge rowEdgeAlpha};
        background-color: ${palette.rgba panel "0.93"};
      }

      element-icon {
        background-color: ${palette.rgba accent "0.09"};
        padding: 6px;
        size: 28px;
        horizontal-align: 0.5;
        vertical-align: 0.5;
        border-radius: 12px;
      }

      element-text {
        horizontal-align: 0;
        vertical-align: 0.5;
        text-color: ${text};
        font: "DepartureMono Nerd Font Mono 12";
      }

      element selected {
        background-color: ${selBg};
        border-color: ${selEdge};
        text-color: ${selFg};
      }

      element selected element-text {
        text-color: ${selFg};
      }

      element selected element-icon {
        background-color: ${palette.rgba selFg "0.16"};
      }

      element alternate {
        background-color: ${palette.rgba alt altAlpha};
      }

      message {
        margin: 8px 10px 0px 10px;
        padding: 10px 14px;
        background-color: ${palette.rgba msg msgAlpha};
        border: 1px;
        border-color: ${palette.rgba edge "0.4"};
        border-radius: 16px;
      }

      textbox {
        text-color: ${accent};
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
    ground = palette.paperDark;
    dot = palette.panelDark;
  };

  light = rasi {
    polka = "polka-light.svg";
    ground = palette.paper;
    panel = palette.paper;
    panelAlpha = "0.92";
    text = palette.ink;
    placeholderAlpha = "0.52";
    accent = palette.plum;
    edge = palette.pink;
    edgeAlpha = "0.96";
    rowEdge = palette.blush;
    rowEdgeAlpha = "0.94";
    # Same wash as in dark, only lighter — and white text would drown in it,
    # so the selected row keeps the body text colour
    selBg = palette.rgba palette.pink "0.45";
    selEdge = palette.plum;
    selFg = palette.ink;
    alt = palette.dot;
    altAlpha = "0.55";
    msg = palette.dot;
    msgAlpha = "0.77";
  };

  dark = rasi {
    polka = "polka-dark.svg";
    ground = palette.paperDark;
    panel = palette.panelDark;
    panelAlpha = "0.92";
    text = palette.textOnDark;
    placeholderAlpha = "0.48";
    accent = palette.pink;
    edge = palette.pink;
    edgeAlpha = "0.72";
    rowEdge = palette.plum;
    rowEdgeAlpha = "0.55";
    # The only opaque surface in the theme would read as a sticker on the dark ground,
    # and the pink edge would vanish into it. Translucent it sits in the same material
    selBg = palette.rgba palette.plum "0.55";
    selEdge = palette.pink;
    selFg = palette.textOnDark;
    alt = palette.panelDark;
    altAlpha = "0.96";
    msg = palette.panelDark;
    msgAlpha = "0.77";
  };
}
