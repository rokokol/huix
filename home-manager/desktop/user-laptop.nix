{ huixDir, rokokolName, ... }:

let
  homeDir = "/home/${rokokolName}";
  myWikiDir = "${homeDir}/myWiki";
  downloadsDir = "${homeDir}/Downloads";
  projectsDir = "${homeDir}/Projects";
  tempDir = "${homeDir}/Temp";
in
{
  imports = [
    ./common-packages.nix
    ./laptop-packages.nix
  ];

  home.stateVersion = "25.11";
  home.file.".face".source = ../../logo.jpg;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

    music = "${myWikiDir}/music";
    documents = "${homeDir}/Documents";
    pictures = "${homeDir}/Pictures";
    videos = "${homeDir}/Videos";

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
      "file://${myWikiDir}/media/"
      "file:///"
    ];
  };

  home.sessionVariables = {
    MY_WIKI = "${homeDir}/myWiki";
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d ${projectsDir} 0755 - - -"
    "D ${tempDir} 0777 - - -"
  ];

  # Files
  home.file.".octaverc".text = ''
    PS1('>> ');
    # to disable octave warn
    warning('off', 'Octave:graphics-toolkit-gnuplot');
  '';
}
