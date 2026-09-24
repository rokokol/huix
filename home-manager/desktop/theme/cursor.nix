# Sayori Cursor V2 — an animated DDLC-style cursor theme
# Author: sev (https://ko-fi.com/sevverae)
# Original: https://ko-fi.com/s/8e05db90c4
{
  lib,
  pkgs,
  inputs,
  ...
}:

let
  cursorName = "Sayori-Cursor-V2";
  cursorSize = 32;

  sayori-cursor = pkgs.stdenvNoCC.mkDerivation {
    pname = "sayori-cursor";
    version = "2";
    src = builtins.path {
      name = "sayori-cursor-v2-src";
      path = "${inputs.self}/assets/sayori-cursor-v2";
    };
    dontUnpack = true;

    nativeBuildInputs = with pkgs; [
      xcur2png
      imagemagick
      xcursorgen
    ];

    # The shop ships every shape at 32 px only. Hyprland loads an Xcursor theme at
    # size * ceil(scale) and GTK asks for size * 2 on a fractional scale, so on a 1.33
    # screen both get 32 px frames back and show them at half size. Each shape is
    # rebuilt with a second, 64 px copy of every frame; the frames are pixel art, so
    # the copy is a nearest-neighbour 2x and stays crisp
    buildPhase = ''
      runHook preBuild
      mkdir -p work out
      for cursor in $src/cursors/*; do
        [ -L "$cursor" ] && continue
        name=$(basename "$cursor")
        mkdir -p "work/$name"
        xcur2png -q -d "$PWD/work/$name" -c "work/$name.conf" "$cursor"
        while read -r size xhot yhot png delay; do
          [ "$size" = "#size" ] && continue
          big="''${png%.png}-2x.png"
          magick "$png" -filter point -resize 200% "$big"
          printf '%s %s %s %s %s\n' $((size * 2)) $((xhot * 2)) $((yhot * 2)) "$big" "$delay"
        done <"work/$name.conf" >"work/$name-2x.conf"
        cat "work/$name-2x.conf" >>"work/$name.conf"
        xcursorgen "work/$name.conf" "out/$name"
      done
      runHook postBuild
    '';

    # The hash-named aliases are the relative symlinks the theme ships, copied as such
    installPhase = ''
      runHook preInstall
      dest=$out/share/icons/${cursorName}
      mkdir -p "$dest/cursors"
      cp $src/index.theme "$dest/"
      cp out/* "$dest/cursors/"
      find $src/cursors -type l -exec cp -P {} "$dest/cursors/" \;
      runHook postInstall
    '';

    meta = {
      description = "Animated DDLC-style cursor theme by sev";
      homepage = "https://ko-fi.com/s/8e05db90c4";
      # The shop grants no redistribution, so this copy is here for one machine only
      license = lib.licenses.unfree;
      platforms = lib.platforms.linux;
    };
  };
in
{
  home.pointerCursor = {
    enable = true;
    package = sayori-cursor;
    name = cursorName;
    size = cursorSize;
    x11.enable = true;
    gtk.enable = true;
  };
}
