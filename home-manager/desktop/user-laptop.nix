{ pkgs, ... }:

{
  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  home.packages = with pkgs; [
    # programs
    ayugram-desktop
    obsidian
    gnome-disk-utility
    celluloid
    gthumb
    file-roller
    octaveFull
    cheese
    fastfetch

    brightnessctl
  ];

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

  home.sessionVariables = {
    NIXPKGS_ALLOW_UNFREE = "1";
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    HUIX = "$HOME/huix";
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d %h/Projects 0755 - - -"
    "D %h/Temp 0777 - - -"
  ];

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
