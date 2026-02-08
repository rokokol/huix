{ pkgs, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # hyprland & desktop
    kitty
    swww
    hypridle
    hyprlock
    hyprpolkitagent
    waybar
    libsForQt5.qt5.qtwayland
    qt6.qtwayland
    pavucontrol
    brightnessctl
    cliphist
    grim
    slurp
    satty
    hyprpicker
    libnotify
    seahorse
    swayimg

    # programs
    ayugram-desktop
    kdePackages.dolphin
    adwaita-icon-theme
    obsidian
  ];

  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "nvim";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    SSH_ASKPASS = "${pkgs.seahorse}/libexec/seahorse/ssh-askpass";
    SSH_ASKPASS_REQUIRE = "force";
    SSH_AUTH_SOCK = "$XDG_RUNTIME_DIR/keyring/ssh";
  };
}
