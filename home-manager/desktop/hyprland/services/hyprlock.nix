{
  config,
  lib,
  pkgs,
  huixDir,
  palette,
  ...
}:

let
  # hyprlock wants bare hex inside rgb()/rgba()
  bare = c: lib.removePrefix "#" c;
in
# Background is a static image, not a screenshot: compositor would double-apply screen_shader on a screenshot
# Text uses label widgets, not image: label updates asynchronously in ms, image widget blocks on reload_cmd (≥1s latency)
# Labels just cat what hyprlock-quote.sh writes; pushing via SIGUSR2 instead is unsafe — hyprlock's handler
# touches its timer vector without the mutex and allocates, so it deadlocks a busy locker (upstream PR #539)
let
  backgroundImage = "${huixDir}/assets/just-monika.png";
  dialogAsset = "${huixDir}/assets/ddlc-stickers/dialog-box.png";
  quoteScript = "${huixDir}/scripts/hyprlock-quote.sh";

  # Expanded by the shell hyprlock runs label commands through, not baked in at build
  stateDir = "\${XDG_RUNTIME_DIR:-/tmp}/hypr-ddlc";

  # The one frame rate: also handed to the script, so it never renders unread frames.
  # One character per tick at CPS=10; each update costs a /bin/sh, so don't lower it
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

  cfg = config.custom.hyprlock;
in
{
  options.custom.hyprlock = {
    dialog = lib.mkOption {
      type = lib.types.bool;
      description = ''
        Monika's dialog box: the box image, the typed quotes and the name plate. Costs two labels
        polled at ${toString pollMs} ms, each spawning a shell, plus the hyprlock-quote.sh loop.
        Off leaves the background, clock, date, layout and input field
      '';
    };

    glitch = lib.mkOption {
      type = lib.types.bool;
      default = cfg.dialog;
      description = ''
        Garble the dialog on a wrong password and at random intervals. Adds a journalctl follower;
        the full-screen flash also needs scripts/screen-shader.sh, and degrades to text-only
        garbling without it
      '';
    };

    # Geometry above is the only source of TEXT_W/FONT_PX — hypridle.nix consumes this
    lockCommand = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default =
        if cfg.dialog then
          "STATE_DIR=\"${stateDir}\" TEXT_W=${toString textW} FONT_PX=${toString fontPx} POLL_MS=${toString pollMs} GLITCH=${if cfg.glitch then "1" else "0"} ${quoteScript} lock"
        else
          lib.getExe config.programs.hyprlock.package;
      description = "command that runs a lock: hyprlock, plus its dialog animation when enabled";
    };
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
          color = "rgb(${bare palette.paperDark})"; # shows until the image loads
        }
      ];

      # The dialog box is static, the text lives in labels on top.
      image = lib.optionals cfg.dialog [
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

      label = map mkLabel ([
        # Clock
        {
          text = "$TIME";
          font_size = 150;
          color = "rgba(${bare palette.paper}ff)";
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
          color = "rgba(${bare palette.paper}e6)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(9f543caa)"; # dark orange from the background
          position = "0, -250";
          halign = "center";
          valign = "top";
        }
        # Layout to the right of the input field ($LAYOUT updates itself)
        {
          text = "$LAYOUT[EN,RU]";
          font_size = 24;
          color = "rgba(${bare palette.paper}dd)";
          shadow_passes = 2;
          shadow_size = 3;
          shadow_color = "rgba(${bare palette.plum}aa)";
          position = "240, -20";
          halign = "center";
          valign = "center";
        }
      ]
      ++ lib.optionals cfg.dialog [
        # Name on the plate: a separate label (not baked into the PNG) so it
        # glitches together with the text and at the same rate. The pink "outline" is a shadow.
        {
          text = "cmd[update:${toString pollMs}] cat \"${stateDir}/name\"";
          font_size = 28;
          color = "rgba(${bare palette.paper}ff)";
          shadow_passes = 2;
          shadow_size = 6;
          shadow_boost = 2;
          shadow_color = "rgba(${bare palette.plum}ff)";
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
          color = "rgba(${bare palette.paper}ff)";
          shadow_passes = 4;
          shadow_size = 2;
          shadow_boost = 1.6;
          shadow_color = "rgba(${bare palette.ink}ff)";
          text_align = "left";
          zindex = 1; # on top of the box
          position = "0, ${toString quoteY}";
          halign = "center";
          valign = "bottom";
        }
      ]);

      "input-field" = [
        {
          monitor = "";
          size = "380, 64";
          outline_thickness = 4;
          rounding = 22;
          outer_color = "rgb(${bare palette.pink})";
          inner_color = "rgb(${bare palette.paper})";
          font_color = "rgb(${bare palette.plum})";
          font_family = "Doki";
          placeholder_text = "<i>Give me it...~</i>";
          fail_text = "This isn't it... ($ATTEMPTS)";
          # password check is highlighted with the same red as an error
          check_color = "rgb(${bare palette.plum})";
          fail_color = "rgb(${bare palette.error})";
          capslock_color = "rgb(${bare palette.warnLine})";
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
