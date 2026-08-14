# Sayori Cursor V2 — an animated DDLC-style cursor theme
# Author: sev (https://ko-fi.com/sevverae)
# Original: https://ko-fi.com/s/8e05db90c4
{ pkgs, inputs, ... }:

let
  sayori-cursor = pkgs.stdenv.mkDerivation {
    name = "sayori-cursor-v2";
    src = builtins.path {
      name = "sayori-cursor-v2-src";
      path = "${inputs.self}/assets/sayori-cursor-v2";
    };
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/icons/Sayori-Cursor-V2
      cp -a $src/* $out/share/icons/Sayori-Cursor-V2/
    '';
  };

  cursorName = "Sayori-Cursor-V2";
  cursorSize = 32;
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
