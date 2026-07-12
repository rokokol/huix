# X-курсор для экрана логина: голова Сайори. Обычная — курсор по умолчанию,
# глитчнутая — когда курсор наведён на кликабельный элемент (pointer/hand),
# как менялась иконка в самой игре во время глитчей.
{ stdenvNoCC, xcursorgen, imagemagick, inputs }:

let
  # Ассеты — из корня флейка в сторе (см. ${inputs.self} в README)
  head = "${inputs.self}/assets/sddm-cursor/sayori-head.png";
  headGlitch = "${inputs.self}/assets/sddm-cursor/sayori-head-glitch.png";
in
stdenvNoCC.mkDerivation {
  pname = "sayori-cursors";
  version = "1.0";

  dontUnpack = true;

  nativeBuildInputs = [
    xcursorgen
    imagemagick
  ];

  installPhase = ''
    runHook preInstall

    cursors=$out/share/icons/sayori-cursors/cursors
    mkdir -p "$cursors"

    # Масштабируем исходник в несколько размеров и собираем один X-курсор;
    # горячая точка — левый верхний край головы (~10% от размера)
    build_cursor() {
      local png="$1" name="$2"
      local cfg="$name.cfg"
      : > "$cfg"
      for size in 24 32 48 64; do
        magick "$png" -resize "$size"x"$size" "$name-$size.png"
        echo "$size $((size / 10)) $((size / 10)) $name-$size.png" >> "$cfg"
      done
      xcursorgen "$cfg" "$cursors/$name"
    }

    build_cursor ${head} left_ptr
    build_cursor ${headGlitch} pointing_hand

    # Стандартные имена курсоров — симлинки на два собранных
    for alias in default arrow top_left_arrow text xterm ibeam watch wait \
                 progress half-busy crosshair cross left_side right_side \
                 top_side bottom_side size_ver size_hor size_fdiag size_bdiag \
                 fleur move all-scroll not-allowed no-drop question_arrow \
                 whats_this up_arrow; do
      ln -s left_ptr "$cursors/$alias"
    done
    for alias in hand1 hand2 hand pointer openhand grab grabbing closedhand \
                 dnd-none dnd-move dnd-copy dnd-link; do
      ln -s pointing_hand "$cursors/$alias"
    done

    cat > "$out/share/icons/sayori-cursors/index.theme" <<EOF
[Icon Theme]
Name=sayori-cursors
Comment=Голова Сайори (DDLC) как курсор для SDDM
EOF

    runHook postInstall
  '';
}
