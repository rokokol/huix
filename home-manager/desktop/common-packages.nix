{ pkgs, ... }:

{
  dconf.enable = true;
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

    # --- Theming & toolkit integration ---
    gnome-themes-extra
    gsettings-desktop-schemas
    gtk-engine-murrine
    gtk3
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
  ];
}
