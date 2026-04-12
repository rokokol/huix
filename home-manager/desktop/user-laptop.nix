{ config, ... }:

let
  homeDir = config.home.homeDirectory;
  huixDir = "${homeDir}/huix";
  mediaDir = "${homeDir}/myWiki/media";
in
{
  imports = [
    ./common-packages.nix
    ./laptop-packages.nix
  ];

  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

    music = "${homeDir}/Music";
    documents = "${homeDir}/Documents";
    pictures = "${homeDir}/Pictures";
    videos = "${homeDir}/Videos";

    download = "${homeDir}/Downloads";

    desktop = null;
    templates = null;
    publicShare = null;
  };

  gtk = {
    enable = true;
    gtk3.bookmarks = [
      "file://${homeDir}/Downloads/"
      "file://${huixDir}/"
      "file://${homeDir}/Temp/"
      "file://${homeDir}/Projects/"
      "file://${mediaDir}/"
      "file:///"
    ];
  };

  home.sessionVariables = {
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    HUIX = huixDir;
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
