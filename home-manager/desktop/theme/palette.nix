# The one place colours are named in this repo.
#
# The DDLC part is not chosen here — it comes from github:rokokol/ddlc-palette, which reads it
# off ddlc.moe. What is chosen here is everything the site has no answer for: dark-mode grounds
# and the RGB-split pair. Those are marked as such, so it stays obvious which colours have a
# source and which are taste. The urgency levels in between are neither: they only rename or
# shade a measured colour
{ base }:

let
  # #RRGGBB -> { r; g; b; }, and back
  toInt = h: (builtins.fromTOML "v = 0x${h}").v;
  parse = hex: rec {
    r = toInt (builtins.substring 1 2 hex);
    g = toInt (builtins.substring 3 2 hex);
    b = toInt (builtins.substring 5 2 hex);
  };
  hex2 =
    n:
    let
      d = "0123456789ABCDEF";
      v =
        if n < 0 then
          0
        else if n > 255 then
          255
        else
          n;
    in
    builtins.substring (v / 16) 1 d + builtins.substring (builtins.bitAnd v 15) 1 d;
  toHex = c: "#${hex2 c.r}${hex2 c.g}${hex2 c.b}";

  scale =
    f: hex:
    (
      c:
      toHex {
        r = f c.r;
        g = f c.g;
        b = f c.b;
      }
    )
      (parse hex);
  # Toward black / toward white, by a fraction
  darken = k: scale (v: builtins.floor (v * (1.0 - k)));
  lighten = k: scale (v: builtins.floor (v + (255 - v) * k));

  mix =
    k: a: b:
    let
      x = parse a;
      y = parse b;
      m = p: q: builtins.floor (p * (1.0 - k) + q * k);
    in
    toHex {
      r = m x.r y.r;
      g = m x.g y.g;
      b = m x.b y.b;
    };
in
base
// rec {
  # "#RRGGBB" + "0.9" -> "rgba(255, 219, 240, 0.9)". Alpha is a string on purpose:
  # toString 0.9 in Nix renders "0.900000"
  rgba =
    hex: a:
    let
      c = parse hex;
    in
    "rgba(${toString c.r}, ${toString c.g}, ${toString c.b}, ${a})";

  # Dark counterparts. The site is light-only, so these are derived, not measured
  paperDark = mix 0.86 base.plum base.ink; # near-black with a plum cast
  panelDark = lighten 0.08 paperDark;
  textOnDark = mix 0.12 base.paper base.blush; # white with just enough pink to not read as grey

  # Muted text, on either ground
  muted = mix 0.45 base.ink base.paper;
  mutedDark = mix 0.45 textOnDark paperDark;
  # Same recipe on the pink surfaces: toward the ground's own hue, not toward grey
  mutedPink = mix 0.45 base.ink base.plum;

  # Notification urgency — the DDLC set stands in for the usual green/amber/red, so the
  # levels are told apart by how loud the colour is rather than by hue
  okLine = base.dot;
  warnLine = base.sayori;
  critLine = base.bow;
  okBg = lighten 0.88 okLine;
  warnBg = lighten 0.88 warnLine;
  critBg = lighten 0.88 critLine;
  okFg = darken 0.62 okLine;
  warnFg = darken 0.48 warnLine;
  critFg = base.bowShadow; # the bow's own shade reads better than another darken of it
  okSoft = lighten 0.62 okLine;
  warnSoft = lighten 0.62 warnLine;
  critSoft = lighten 0.62 critLine;

  # RGB-split, same pair the greeter uses
  splitCyan = "#00FFFF";
  splitMagenta = "#FF00FF";
}
