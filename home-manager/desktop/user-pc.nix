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
  tempDir = "/tmp/Temp";
in
{
  imports = [
    ./hyprland/hyprland-pc.nix
    ./packages/packages-pc.nix
    ./sync.nix
    ./theme/default.nix
  ];

  home.stateVersion = "25.11";

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

    music = "${myWikiDir}/00. Вложения/02. Music";
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
      "file://${myWikiDir}/"
      "file://${govnoDir}/"
      "file:///"
    ];
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d ${projectsDir} 0755 - - -"
    "D ${tempDir} 0777 - - -"
  ];

  home.sessionVariables = {
    MY_WIKI = "${govnoDir}/myWiki";
  };
}
