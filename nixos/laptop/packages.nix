{ pkgs, ... }:

{
  # --- Core desktop session ---
  programs.zsh.enable = true;
  programs.hyprland.enable = true;

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # --- Gaming & power ---
  programs.steam.enable = true;
  powerManagement.powertop.enable = true;

  nixpkgs.config.allowUnfree = true;

  environment.systemPackages = with pkgs; [
    # --- CLI & development ---
    git
    gh
    ffmpeg-headless
    imagemagick
    jq
    killall
    lazygit
    neovim
    pup
    ripgrep
    trash-cli
    wget

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
