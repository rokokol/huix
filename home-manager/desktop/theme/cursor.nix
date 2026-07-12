{ pkgs, huixDir, ... }:
# Sayori Cursor V2 — анимированная тема курсора в стиле DDLC
# Автор: sev (https://ko-fi.com/sevverae)
# Оригинал: https://ko-fi.com/s/8e05db90c4

let
  sayori-cursor = pkgs.stdenv.mkDerivation {
    name = "sayori-cursor-v2";
    src = "${huixDir}/assets/sayori-cursor-v2";
    dontUnpack = true;
    installPhase = ''
      mkdir -p $out/share/icons/Sayori-Cursor-V2
      cp -a $src/* $out/share/icons/Sayori-Cursor-V2/
    '';
  };
in
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    package = sayori-cursor;
    name = "Sayori-Cursor-V2";
    size = 24;
  };
}
