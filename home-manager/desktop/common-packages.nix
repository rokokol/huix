{ pkgs, huixDir, ... }:

let
  crow-old = pkgs.crow-translate.overrideAttrs (oldAttrs: rec {
    version = "2.11.1";
    src = pkgs.fetchFromGitHub {
      owner = "crow-translate";
      repo = "crow-translate";
      rev = "v${version}";
      # Хэш можно узнать, заменив его на lib.fakeHash,
      # запустив сборку и скопировав полученный из ошибки хэш.
      hash = "sha256-787o6OId/qf6pD1Mv5s86H0A5p5pY5p5pY5p5pY5p5p=";
    };
  });
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
