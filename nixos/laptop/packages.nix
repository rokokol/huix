{ pkgs, ... }:

{
  programs.zsh.enable = true;
  nixpkgs.config.allowUnfree = true;
  programs.hyprland.enable = true;
  security.polkit.enable = true;
  programs.firefox.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;
  programs.steam.enable = true;
  powerManagement.powertop.enable = true;

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

    # --- File management & previews ---
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
