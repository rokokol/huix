{ pkgs, ... }:

{
  fonts.packages = with pkgs; [
    (stdenv.mkDerivation {
      name = "my-fonts";
      src = ../fonts;
      installPhase = ''
        mkdir -p $out/share/fonts/truetype
        mkdir -p $out/share/fonts/opentype
        find $src -name "*.ttf" -exec cp {} $out/share/fonts/truetype/ \;
        find $src -name "*.otf" -exec cp {} $out/share/fonts/opentype/ \;
      '';
    })
    inter
  ];

  fonts.fontconfig.defaultFonts = {
    monospace = [ "DepartureMono Nerd Font Mono" ];
    sansSerif = [ "Inter" ];
    serif = [ "Inter" ];
  };
}

