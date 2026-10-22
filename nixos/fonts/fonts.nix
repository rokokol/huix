{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

let
  myaNunito = inputs.ddlc-themes.lib.mya-nunito;
in
{
  options.rokokol.fonts.enable = lib.mkEnableOption "the desktop fonts" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.fonts.enable {
    fonts.packages = with pkgs; [
      (stdenv.mkDerivation {
        name = "my-fonts";
        # Only the font files: this module and the README live in the same directory, so a
        # bare ../fonts rebuilds the package (and everything downstream) on any edit to them
        src = lib.fileset.toSource {
          root = ../fonts;
          fileset = lib.fileset.unions [
            (lib.fileset.fileFilter (f: f.hasExt "ttf") ../fonts)
            (lib.fileset.fileFilter (f: f.hasExt "otf") ../fonts)
          ];
        };
        installPhase = ''
          mkdir -p $out/share/fonts/truetype
          mkdir -p $out/share/fonts/opentype
          find $src -name "*.ttf" -exec cp {} $out/share/fonts/truetype/ \;
          find $src -name "*.otf" -exec cp {} $out/share/fonts/opentype/ \;
        '';

        meta = {
          description = "Font files this repository carries directly, outside nixpkgs";
          # The set holds Doki, a personal-use font by 538Fonts, so the whole derivation
          # is unfree. ASSETS.md names each file and its owner
          license = lib.licenses.unfree;
          platforms = lib.platforms.all;
        };
      })
      inter
      # The prose face of the DDLC themes, and the headings' face where Doki is missing
      nunito
      # Nunito with the Greek and mathematics it lacks: the variable family "Mya Nunito" and the
      # static weights as "Mya Nunito Static", which apps that read no variation axis need
      (runCommand "mya-nunito-fonts"
        {
          meta = {
            description = "Mya Nunito, Nunito merged with Noto Greek and mathematics, from ddlc-themes";
            license = lib.licenses.ofl;
            platforms = lib.platforms.all;
          };
        }
        ''
          mkdir -p $out/share/fonts/truetype
          # The flake exports each file as a store path of its own, with a hash before the name
          for font in ${
            lib.escapeShellArgs (
              [
                myaNunito.ttf.regular
                myaNunito.ttf.italic
              ]
              ++ lib.attrValues myaNunito.static
            )
          }; do
            name=$(basename "$font")
            cp "$font" "$out/share/fonts/truetype/''${name#*-}"
          done
        ''
      )
      (google-fonts.override { fonts = [ "Spectral" ]; })
    ];

    fonts.fontconfig.defaultFonts = {
      monospace = [ "DepartureMono Nerd Font Mono" ];
      sansSerif = [ "Nunito" ];
      serif = [ "Spectral" ];
    };
  };
}
