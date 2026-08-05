# DDLC theme derivation for SDDM (Qt6, Theme-API 2.0).
# QML files are named in CamelCase — a QML requirement (the file name sets the
# type name), a deliberate exception to the repo-wide kebab-case rule
{ stdenvNoCC, imagemagick, inputs }:

let
  # Stickers are taken from the repo's shared assets (via builtins.path to isolate the hash)
  stickers = builtins.path {
    name = "ddlc-stickers";
    path = "${inputs.self}/assets/ddlc-stickers";
  };
in
stdenvNoCC.mkDerivation {
  pname = "sddm-ddlc-theme";
  version = "1.0";

  src = ./theme;

  nativeBuildInputs = [ imagemagick ];

  installPhase = ''
    runHook preInstall

    theme=$out/share/sddm/themes/ddlc
    mkdir -p "$theme/assets"
    cp -r ./. "$theme/"

    # All stickers are stored as PNG (Qt6 in the greeter can't read webp
    # without qtimageformats) — just copy them: plain, cut (-cut) and distorted
    cp ${stickers}/*-sticker-*.png "$theme/assets/"

    # The game's "Just Monika" menu image — for the easter-egg dialogs
    cp ${stickers}/just-monika-ok.png "$theme/assets/"

    # Gray noise tile for the background grain
    magick -size 240x240 xc:gray50 +noise Random -colorspace Gray "$theme/assets/noise.png"

    runHook postInstall
  '';
}
