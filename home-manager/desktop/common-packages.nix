{ pkgs, huixDir, ... }:

let
  crow-old = pkgs.libsForQt5.callPackage (
    {
      stdenv,
      fetchFromGitHub,
      cmake,
      qtbase,
      qtx11extras,
      qtmultimedia,
      qttools,
      qtsvg,
      kwayland,
      leptonica,
      tesseract,
      extra-cmake-modules,
      wrapQtAppsHook,
      pkg-config,
      libxdmcp,
      libxau,
    }:
    stdenv.mkDerivation rec {
      pname = "crow-translate";
      version = "2.11.1";

      src = fetchFromGitHub {
        owner = "crow-translate";
        repo = "crow-translate";
        rev = version;
        hash = "sha256-fvo/IdCdvbKD77+5etPmsw2tG6qbgFPInqPKc54Q2h0=";
        fetchSubmodules = true;
      };

      nativeBuildInputs = [
        cmake
        extra-cmake-modules
        qttools
        wrapQtAppsHook
        pkg-config
      ];

      cmakeFlags = [
        "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      ];

      buildInputs = [
        qtbase
        qtx11extras
        qtsvg
        qtmultimedia
        qtmultimedia
        kwayland
        leptonica
        tesseract
        libxdmcp
        libxau
      ];
    }
  ) { };
in
{
  imports = [
    ./mime-apps.nix
    ./theme.nix
  ];

  home.packages = with pkgs; [
    # --- Common desktop apps ---
    baobab
    celluloid
    codex
    gemini-cli
    evince
    file-roller
    gnome-disk-utility
    gnome-text-editor
    gthumb
    texlive.combined.scheme-full
    usbutils
    yt-dlp
    matlab
    libreoffice-fresh
    exiftool
    tree
    crow-old

    # Python
    uv
    python313

    # --- Theming & toolkit integration ---
    gnome-themes-extra
    gsettings-desktop-schemas
    gtk-engine-murrine
    gtk3
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
  ];

  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    TERMINAL = "kitty";
    HUIX = huixDir;
    NIXOS_OZONE_WL = "1";
  };

  home.file.".config/matlab/nix.sh".text = ''
    INSTALL_DIR=$HOME/MATLAB2025a/ 
  '';
}
