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
  postPatch = "patchShebangs themes/install.sh";

  # Default install ships Light/Dark (+hdpi/xhdpi), which is all we toggle between
  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/themes
    cd themes
    ./install.sh -n Gruvbox -d "$out/share/themes"
    runHook postInstall
  '';
}
