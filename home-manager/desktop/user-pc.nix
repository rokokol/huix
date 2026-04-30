{
  govnoDir,
  huixDir,
  rokokolName,
  ...
}:

let
  homeDir = "/home/${rokokolName}";
  myWikiDir = "${govnoDir}/myWiki";
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

    music = "${myWikiDir}/music";
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
      "file://${myWikiDir}/media/"
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

  home.sessionVariables = {
    MY_WIKI = "${govnoDir}/myWiki";
  };
}
