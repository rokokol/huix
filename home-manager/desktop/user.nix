{ pkgs, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  # Global packages not bound to specific program configs
  home.packages = with pkgs; [

  ];

  xdg.userDirs = {
    enable = true;
    createDirectories = false;
    music = "/home/rokokol/govno/Music";
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d %h/notebooks 0755 - - -"
    "d %h/Projects 0755 - - -"
    "d %h/Screenshots 0700 - - 30d"
    "D %h/Temp 0777 - - -"
  ];

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';

  # Global session variables
  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
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
}
