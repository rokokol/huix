{ pkgs, ... }:

{
  # ============================================================================
  #  PROGRAMS & SERVICES CONFIGURATION
  # ============================================================================

  # --- Core & Shell ---
  programs.hyprland.enable = true;
  programs.zsh.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # --- Internet & Privacy ---
  programs.firefox.enable = true;
  programs.amnezia-vpn.enable = true;
  services.tor.enable = true;
  services.tor.client.enable = true;

  # --- Desktop Environment Integrations ---
  services.flatpak.enable = true;
  programs.appimage.enable = true;

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
    lazygit
    wl-clipboard
    wl-clip-persist
    imagemagick
    killall
    pup
    jq
    translate-shell
    file

    thunar
    cuda.ffmpegthumbnailer
    poppler
    libgsf
    cuda.ffmpeg-full

    (pkgs.catppuccin-sddm.override {
      flavor = "mocha";
      accent = "maroon";
    })
  ];

  # Exclude basic X11 terminal
  services.xserver.excludePackages = [ pkgs.xterm ];
}
