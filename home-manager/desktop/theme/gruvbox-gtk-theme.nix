# Vendored because nixpkgs dropped gruvbox-gtk-theme along with its GTK2 murrine engine.
# murrine is skipped on purpose — it only backs the unused gtk-2.0 subtheme
{
  stdenvNoCC,
  fetchFromGitHub,
  sassc,
  gnome-themes-extra,
}:

stdenvNoCC.mkDerivation {
  pname = "gruvbox-gtk-theme";
  version = "0-unstable-2025-10-23";

  src = fetchFromGitHub {
    owner = "Fausto-Korpsvart";
    repo = "Gruvbox-GTK-Theme";
    rev = "578cd220b5ff6e86b078a6111d26bb20ec8c733f";
    hash = "sha256-RXoPj/aj9OCTIi8xWatG0QpDAUh102nFOipdSIiqt7o=";
  };

  nativeBuildInputs = [ sassc ];
  buildInputs = [ gnome-themes-extra ];

  dontBuild = true;
  # Accent recoloured to ddlc-palette's "yuri" (#6C4681) instead of gruvbox's default blue
  postPatch = ''
    patchShebangs themes/install.sh
    substituteInPlace themes/src/sass/_color-palette-default.scss \
      --replace-fail '$default-light: $blue-light;' '$default-light: #6C4681;' \
      --replace-fail '$default-dark: $blue-dark;' '$default-dark: #6C4681;'
  '';

  # Default install ships Light/Dark (+hdpi/xhdpi), which is all we toggle between
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/themes
    cd themes
    ./install.sh -n Gruvbox -d "$out/share/themes"
    runHook postInstall
  '';

  # libadwaita only honours the colour definitions, so ship them split out: the
  # full sheet costs ~15ms to parse per GTK4 app (vs 0.12ms) and does icon lookups
  postInstall = ''
    for dir in $out/share/themes/*/gtk-4.0; do
      grep '^@define-color' "$dir/gtk.css" >"$dir/gtk-colors.css"
    done
  '';
}
