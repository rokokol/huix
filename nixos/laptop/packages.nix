{ pkgs, ... }:

{
  # --- Core desktop session ---
  programs.zsh.enable = true;
  programs.hyprland.enable = true;
  programs.firefox.enable = true;

  # --- Permissions & removable devices ---
  security.polkit.enable = true;
  services.udisks2.enable = true;

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # --- File management & thumbnails ---
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  # --- Gaming & power ---
  programs.steam.enable = true;
  powerManagement.powertop.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # --- CLI & development ---
    git
    gh
    imagemagick
    jq
    killall
    lazygit
    neovim
    pup
    ripgrep
    translate-shell
    wget
    wl-clipboard
    wl-clip-persist

    # --- Files, previews & desktop helpers ---
    ffmpeg-full
    ffmpegthumbnailer
    libgsf
    poppler
    thunar
    trash-cli
    tumbler

    # --- Power & OCR ---
    powertop
    (tesseract5.override {
      enableLanguages = [
        "rus"
        "eng"
      ];
    })
  ];

  # Remove X11 term
  services.xserver.excludePackages = [ pkgs.xterm ];
}
