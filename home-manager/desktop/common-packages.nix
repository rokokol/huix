{ pkgs, huixDir, ... }:

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
