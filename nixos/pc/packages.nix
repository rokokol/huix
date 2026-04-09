{ pkgs, ... }:

{
  # --- Core desktop session ---
  programs.hyprland.enable = true;
  programs.zsh.enable = true;

  # --- File management & thumbnails ---
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # --- Browser & privacy ---
  programs.firefox.enable = true;

  # --- Desktop app integration ---
  programs.appimage.enable = true;
  services.flatpak.enable = true;

  # --- Gaming ---
  programs.steam.enable = true;

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

    # --- Files, previews & desktop helpers ---
    cuda.ffmpeg-full
    cuda.ffmpegthumbnailer
    libgsf
    poppler
    thunar
  ];

  # Exclude basic X11 terminal
  services.xserver.excludePackages = [ pkgs.xterm ];
}
