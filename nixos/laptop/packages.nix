{ pkgs, ... }:

{
  nixpkgs.config.allowUnfree = true;
  programs.hyprland.enable = true;
  security.polkit.enable = true;
  programs.firefox.enable = true;
  programs.amnezia-vpn.enable = true;
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
  security.pam.services.hyprland.enableGnomeKeyring = true;
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  services.tumbler.enable = true;

  environment.systemPackages = with pkgs; [
    neovim
    wget
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
    tumbler
    ffmpegthumbnailer
    poppler
    libgsf
    ffmpeg-full

    octaveFull

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

  # Remove X11 term
  services.xserver.excludePackages = [ pkgs.xterm ];
}
