{ pkgs, ... }:

{
  # ============================================================================
  #  PROGRAMS & SERVICES CONFIGURATION
  # ============================================================================

  # --- Core & Shell ---
  programs.gnupg.agent.enable = true;
  programs.hyprland.enable = true;
  programs.zsh.enable = true;
  services.tumbler.enable = true;
  services.gvfs.enable = true;

  # --- Internet & Privacy ---
  programs.firefox.enable = true;
  programs.amnezia-vpn.enable = true;
  services.tor.enable = true;
  services.tor.client.enable = true;
  programs.geary.enable = true;

  # --- Desktop Environment Integrations ---
  services.flatpak.enable = true;
  programs.appimage.enable = true;
  services.zeitgeist.enable = true;

  # --- Gaming ---
  programs.steam.enable = true;

  # ============================================================================
  #  SYSTEM PACKAGES
  # ============================================================================

  environment.systemPackages = with pkgs; [
    # --- 1. CORE UTILITIES & CLI ---
    wget
    curl
    git
    gh
    wl-clipboard
    wl-clip-persist
    gtk3
    dex
    imagemagick
    killall
    pup
    jq
    translate-shell
    gnome-keyring
    gcr
    seahorse
    libsecret

    thunar
    ffmpegthumbnailer
    poppler
    libgsf
    ffmpeg-full

    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "maroon";
    })
    (tesseract5.override {
      enableLanguages = [
        "rus"
        "eng"
      ];
    })
  ];

  # Exclude basic X11 terminal
  services.xserver.excludePackages = [ pkgs.xterm ];
}
