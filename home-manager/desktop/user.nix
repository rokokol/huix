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
    createDirectories = true;

    music = "/home/rokokol/govno/Music";
    documents = "/home/rokokol/govno/Documents";
    pictures = "/home/rokokol/govno/Pictures";
    videos = "/home/rokokol/govno/Videos";

    download = "/home/rokokol/Downloads";

    desktop = null;
    templates = null;
    publicShare = null;
  };

  gtk = {
    enable = true;
    gtk3.bookmarks = [
      "file:///home/rokokol/Downloads/"
      "file:///home/rokokol/huix/"
      "file:///home/rokokol/Temp/"
      "file:///home/rokokol/myWiki/media/"
      "file:///"
    ];
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d %h/notebooks 0755 - - -"
    "d %h/Projects 0755 - - -"
    "d %h/govno/Pictures/Screenshots 0700 - - 30d"
    "D %h/Temp 0777 - - -"
  ];

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';

  home.file.".config/matlab/nix.sh".text = ''
    INSTALL_DIR=$HOME/MATLAB2025a/ 
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
