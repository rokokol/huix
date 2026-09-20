{
  huixDir,
  myWikiDir,
  rokokolName,
  ...
}:

let
  homeDir = "/home/${rokokolName}";
  downloadsDir = "${homeDir}/Downloads";
  projectsDir = "${homeDir}/Projects";
  tempDir = "/tmp/Temp";
in
{
  imports = [
    ./hyprland/hyprland.nix
    ./packages/packages.nix
    ./sync.nix
    ./theme/default.nix
  ];

  home.stateVersion = "25.11";
  programs.home-manager.enable = true;

  xdg.userDirs = {
    enable = true;
    createDirectories = true;
    setSessionVariables = true;

    music = "${myWikiDir}/00. Вложения/02. Music";
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
      "file://${myWikiDir}/"
      "file:///"
    ];
  };

  # Directories
  systemd.user.tmpfiles.rules = [
    "d ${projectsDir} 0755 - - -"
    "D ${tempDir} 0777 - - -"
  ];

  home.sessionVariables = {
    MY_WIKI = myWikiDir;
  };
}
