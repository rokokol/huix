{ pkgs, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";

  home.packages = with pkgs; [
    # programs
    ayugram-desktop
    adwaita-icon-theme
    obsidian
    bambu-studio
    gnome-disk-utility
    celluloid
    swayimg
    gthumb
    file-roller
    octaveFull
  ];

  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "firefox";
  };
}
