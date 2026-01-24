{ config, pkgs, ... }:

{
  imports = [
    ./programs/zsh.nix
    ./programs/git.nix
    ./programs/neovim.nix
    ./programs/starship.nix
    ./programs/kitty.nix
    ./desktop/gnome.nix
    ./desktop/desktop-entries.nix
    ./desktop/mime.nix
  ];

  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";

  # Global packages not bound to specific program configs
  home.packages = with pkgs; [
    #    nautilus-open-any-terminal
  ];

  # Global session variables
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
    PAGER = "nvim -R"; # Read-only
    MANPAGER = "nvim +Man!";
    QT_QPA_PLATFORM = "wayland";
    SDL_VIDEODRIVER = "wayland";
    XDG_CURRENT_DESKTOP = "GNOME";
    TERMINAL = "kitty";
    BROWSER = "firefox";
  };

  programs.home-manager.enable = true;
  programs.bash.enable = true;
}


