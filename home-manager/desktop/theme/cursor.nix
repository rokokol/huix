# Sayori Cursor V2 — анимированная тема курсора в стиле DDLC
# Автор: sev (https://ko-fi.com/sevverae)
# Оригинал: https://ko-fi.com/s/8e05db90c4
{ pkgs, inputs, ... }:

let
  sayori-cursor = pkgs.stdenv.mkDerivation {
    name = "sayori-cursor-v2";
    src = "${inputs.self}/assets/sayori-cursor-v2";
    dontUnpack = true;
    nativeBuildInputs = [
      pkgs.zip
      pkgs.unzip
    ];
    installPhase = ''
      out_theme=$out/share/icons/Sayori-Cursor-V2
      mkdir -p $out_theme
      cp -a $src/* $out_theme/
      chmod -R u+w $out_theme
      #
      # # Тема нарисована в единственном размере (32) с resize_algorithm = none.
      # # На мониторе с дробным scale (у ноута eDP-1 scale = 1.33) компоситору нужен
      # # битмап 32*1.33 ≈ 43px, а «none» запрещает масштабирование → hyprcursor
      # # отдаёт 32px и курсор выглядит не того размера / мерцает. Перепаковываем
      # # каждый .hlc с bilinear, чтобы hyprcursor мог отдать нужный дробный размер.
      # for hlc in $out_theme/hyprcursors/*.hlc; do
      #   work=$(mktemp -d)
      #   unzip -oq "$hlc" -d "$work"
      #   sed -i 's/^resize_algorithm = none/resize_algorithm = bilinear/' "$work/meta.hl"
      #   rm "$hlc"
      #   ( cd "$work" && zip -qr "$hlc" . )
      # done
    '';
  };

  cursorName = "Sayori-Cursor-V2";
  cursorSize = 32;
in
{
  home.pointerCursor = {
    gtk.enable = true;
    x11.enable = true;
    # # hyprcursor выставляет HYPRCURSOR_THEME/HYPRCURSOR_SIZE — без них нативные
    # # Wayland-приложения (и cursor-shape-клиенты вроде slurp) рендерят hyprcursor
    # # в дефолтном размере, а не в заданном 32.
    # hyprcursor = {
    #   enable = true;
    #   size = cursorSize;
    # };
    package = sayori-cursor;
    name = cursorName;
    size = cursorSize;
  };
}
