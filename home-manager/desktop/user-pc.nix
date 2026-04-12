{
  config,
  pkgs,
  ...
}:

let
  homeDir = config.home.homeDirectory;
  huixDir = "${homeDir}/huix";
  mediaDir = "${homeDir}/myWiki/media";
  sharedDataDir = "${homeDir}/govno";
in
{
  imports = [
    ./common-packages.nix
    ./pc-packages.nix
  ];

  home.username = "rokokol";
  home.homeDirectory = "/home/rokokol";
  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

    music = "${sharedDataDir}/Music";
    documents = "${sharedDataDir}/Documents";
    pictures = "${sharedDataDir}/Pictures";
    videos = "${sharedDataDir}/Videos";

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
      "file://${sharedDataDir}/"
      "file:///"
    ];
  };

  # Directories
  systemd.user.tmpfiles.rules = [
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
    EDITOR = "nvim";
    TERMINAL = "kitty";
    BROWSER = "firefox";
    HUIX = huixDir;
  };

  xdg.dataFile = {
    "v2rayN/bin/sing_box/sing-box".source = "${pkgs.sing-box}/bin/sing-box";
    "v2rayN/bin/xray/xray".source = "${pkgs.xray}/bin/xray";
    "v2rayN/bin/geoip.dat".source = "${pkgs.v2ray-geoip}/share/v2ray/geoip.dat";
    "v2rayN/bin/geosite.dat".source = "${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat";
  };
}
