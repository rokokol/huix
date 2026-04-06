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
    neovim
    wget
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
    ripgrep

    thunar
    tumbler
    ffmpegthumbnailer
    poppler
    libgsf
    ffmpeg-full
    trash-cli
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
