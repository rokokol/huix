# X cursor for the login screen: Sayori's head. The plain one is the default
# cursor, the glitched one is shown when the cursor hovers a clickable element
# (pointer/hand), just like the icon changed in the game itself during glitches
{ stdenvNoCC, xcursorgen, imagemagick, inputs }:

let
  # Assets go through builtins.path so the hash depends only on the cursor
  # folder, not on the whole repo (inputs.self changes on every commit)
  assetDir = builtins.path {
    name = "sddm-cursor-assets";
    path = "${inputs.self}/assets/sddm-cursor";
  };
  head = "${assetDir}/sayori-head.png";
  headGlitch = "${assetDir}/sayori-head-glitch.png";
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

    # Scale the source into several sizes and assemble one X cursor;
    # the hotspot is the top-left edge of the head (~10% of the size)
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

    # Standard cursor names — symlinks to the two built ones
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
Comment=Sayori's head (DDLC) as a cursor for SDDM
EOF

    runHook postInstall
  '';
}
