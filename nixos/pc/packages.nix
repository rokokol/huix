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
    # --- CLI & development ---
    curl
    file
    git
    gh
    imagemagick
    jq
    killall
    lazygit
    pup
    ripgrep
    translate-shell
    wget
    wl-clipboard
    wl-clip-persist

    # --- File management & previews ---
    cuda.ffmpeg-full
    cuda.ffmpegthumbnailer
    libgsf
    poppler
    thunar
  ];

  # Exclude basic X11 terminal
  services.xserver.excludePackages = [ pkgs.xterm ];
}
