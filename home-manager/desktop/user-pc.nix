{
  govnoDir,
  huixDir,
  pkgs,
  rokokolName,
  ...
}:

let
  homeDir = "/home/${rokokolName}";
  downloadsDir = "${homeDir}/Downloads";
  projectsDir = "${homeDir}/Projects";
  tempDir = "${homeDir}/Temp";
in
{
  imports = [
    ./common-packages.nix
    ./pc-packages.nix
  ];

  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

    music = "${govnoDir}/Music";
    documents = "${govnoDir}/Documents";
    pictures = "${govnoDir}/Pictures";
    videos = "${govnoDir}/Videos";

    download = downloadsDir;

    desktop = null;
    templates = null;
    publicShare = null;
  };

  gtk = {
    enable = true;
    gtk3.bookmarks = [
      "file://${downloadsDir}/"
      "file://${huixDir}/"
      "file://${tempDir}/"
      "file://${projectsDir}/"
      "file://${homeDir}/myWiki/media/"
      "file://${govnoDir}/"
      "file:///"
    ];
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d ${projectsDir} 0755 - - -"
    "d ${govnoDir}/Pictures/Screenshots 0700 - - 30d"
    "D ${tempDir} 0777 - - -"
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
