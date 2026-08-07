{ lib, huixDir, ... }:

# Background is a static image, not a screenshot: compositor would double-apply screen_shader on a screenshot
# Text uses label widgets, not image: label updates asynchronously in ms, image widget blocks on reload_cmd (≥1s latency)
# The dialog labels only `cat` what hyprlock-quote.sh renders, so the poll is cheap and hyprlock owns the clock.
# Deliberately NOT the cmd[update:0:1] + SIGUSR2 push: hyprlock's handler walks its timer vector without taking
# timersMutex and does allocating work inside the handler, so signalling a busy locker races or deadlocks it
let
  backgroundImage = "${huixDir}/assets/just-monika.png";
  dialogAsset = "${huixDir}/assets/ddlc-stickers/dialog-box.png";
  quoteScript = "${huixDir}/scripts/hyprlock-quote.sh";

  # Where the script publishes the rendered dialog; expanded by the shell that
  # hyprlock runs label commands through, so nothing is baked to an absolute path
  stateDir = "\${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc";

  # The one frame rate of the lock screen: hyprlock polls the labels this often and
  # the script is handed the same number, so it never renders frames nobody reads.
  # Matches CPS=10 (one revealed character per tick); each update costs a /bin/sh,
  # so halving this doubles the cost of the whole lock screen
  pollMs = 100;

  # Asset geometry: a 1280x720 canvas, the visible box on it (x-centered, with a
  # transparent tail at the bottom) and its internals, in canvas px.
  src = {
    w = 1280;
    h = 720;
    boxY = 527; # top of the box on the canvas
    boxW = 816;
    boxH = 185;
    insetX = 40; # text-area padding inside the box
    menuH = 35; # menu strip along the bottom of the box
    plateCx = 118; # center of the name plate from the box top-left
    plateCy = 19;
  };

  boxH = 280; # box height on screen; the rest is derived
  bottom = 30; # box offset from the bottom of the screen
  k = boxH / (1.0 * src.boxH);
  px = v: builtins.floor (v * k + 0.5);

  imgSize = px src.h; # widget size = shorter canvas side (height)
  imgY = bottom - px (src.h - src.boxY - src.boxH); # compensate for the canvas tail
  textW = px (src.boxW - 2 * src.insetX); # text-area width
  quoteY = bottom + px src.menuH - 6; # bottom of the line label (above the menu)
  nameX = px (src.plateCx - src.boxW / 2); # plate center from the screen center
  nameY = bottom + px (src.boxH - src.plateCy) - 24; # bottom of the name label

  quoteFontSize = 24;
  fontPx = quoteFontSize * 4 / 3; # pango pt -> px @ 96dpi: wrapping metrics

  # All labels — on every monitor and in one font.
  mkLabel =
    l:
    {
      monitor = "";
      font_family = "Doki";
    }
    // l;
in
{
  # The geometry above is the only source of TEXT_W/FONT_PX, so the lock command
  # is assembled here and consumed by hypridle.nix rather than re-derived there
  options.custom.hyprlock.lockCommand = lib.mkOption {
    type = lib.types.str;
    readOnly = true;
    default = "STATE_DIR=\"${stateDir}\" TEXT_W=${toString textW} FONT_PX=${toString fontPx} POLL_MS=${toString pollMs} ${quoteScript} lock";
    description = "command that runs a lock: hyprlock plus its dialog animation";
  };

  config.programs.hyprlock = {
    enable = true;

    settings = {
      general = {
        hide_cursor = true;
        ignore_empty_input = true;
        # the line frame is padded with blank lines to a constant height —
        # trimming would collapse the texture and the text would jump
        text_trim = false;
      };

      # Smooth lock-screen fade-in.
      animations = {
        enabled = true;
        bezier = "linear, 1, 1, 0, 0";
        animation = [
          "fadeIn, 1, 6, linear"
          "fadeOut, 1, 3, linear"
        ];
      };

      background = [
        {
          monitor = "";
          path = backgroundImage;
          color = "rgb(2a1a2e)"; # fallback color
        }
      ];

      # The dialog box is static, the text lives in labels on top.
      image = [
        {
          monitor = "";
          path = dialogAsset;
          size = imgSize;
          rounding = 0;
          border_size = 0;
          zindex = 0; # zindex sorting is unstable — pin it explicitly
          position = "0, ${toString imgY}";
          halign = "center";
          valign = "bottom";
        }
      ];

      label = map mkLabel [
        # Clock
        {
          text = "$TIME";
          font_size = 150;
          color = "rgba(ffffffff)";
          shadow_passes = 3;
          shadow_size = 6;
          shadow_color = "rgba(bf936edd)"; # warm copper-beige from the background
          position = "0, -70";
          halign = "center";
          valign = "top";
        }
        # Date (tr -d: text_trim is off, a trailing \n would become a second line)
        {
          text = ''cmd[update:60000] date +"%A, %B %-d" | tr -d '\n' '';
          font_size = 30;
          color = "rgba(ffffffe6)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(9f543caa)"; # dark orange from the background
          position = "0, -250";
          halign = "center";
          valign = "top";
        }
        # Name on the plate: a separate label (not baked into the PNG) so it
        # glitches together with the text and at the same rate. The pink "outline" is a shadow.
        {
          text = "cmd[update:${toString pollMs}] cat \"${stateDir}/name\"";
          font_size = 28;
          color = "rgba(ffffffff)";
          shadow_passes = 2;
          shadow_size = 6;
          shadow_boost = 2;
          shadow_color = "rgba(e2679bff)";
          zindex = 2;
          position = "${toString nameX}, ${toString nameY}";
          halign = "center";
          valign = "bottom";
        }
        # Line: a constant texture size (see the header) + halign center
        # + valign bottom pin the top-left of the text right at the text-area
        # padding. The black "outline" is a shadow.
        {
          text = "cmd[update:${toString pollMs}] cat \"${stateDir}/frame\"";
          font_size = quoteFontSize;
          color = "rgba(ffffffff)";
          shadow_passes = 4;
          shadow_size = 2;
          shadow_boost = 1.6;
          shadow_color = "rgba(000000ff)";
          text_align = "left";
          zindex = 1; # on top of the box
          position = "0, ${toString quoteY}";
          halign = "center";
          valign = "bottom";
        }
        # Layout to the right of the input field ($LAYOUT updates itself)
        {
          text = "$LAYOUT[EN,RU]";
          font_size = 24;
          color = "rgba(ffffffdd)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(e2679baa)";
          position = "240, -20";
          halign = "center";
          valign = "center";
        }
      ];

      "input-field" = [
        {
          monitor = "";
          size = "380, 64";
          outline_thickness = 4;
          rounding = 22;
          outer_color = "rgb(ff7fbf)";
          inner_color = "rgb(ffffff)";
          font_color = "rgb(b3487f)";
          font_family = "Doki";
          placeholder_text = "<i>Give me it...~</i>";
          fail_text = "This isn't it... ($ATTEMPTS)";
          # password check is highlighted with the same red as an error
          check_color = "rgb(d64d7a)";
          fail_color = "rgb(d64d7a)";
          capslock_color = "rgb(ffb347)";
          dots_text_format = "♥";
          dots_spacing = 0.2;
          fade_on_empty = false;
          position = "0, -20";
          halign = "center";
          valign = "center";
        }
      ];
    };
  };
}
