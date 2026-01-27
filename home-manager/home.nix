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
  ];

  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";
  home.file.".face".source = ../logo.jpg;

  # Global packages not bound to specific program configs
  home.packages = with pkgs; [
  ];

  # Directories
  systemd.user.tmpfiles.rules = [
    "d %h/notebooks 0755 - - -"
    "d %h/Projects 0755 - - -"
    "d %h/Screenshots 0700 - - 30d"
  ];

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';

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


