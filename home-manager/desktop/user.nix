{
  config,
  lib,
  huixDir,
  myWikiDir,
  rokokolName,
  ...
}:

let
  cfg = config.rokokol.home;
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

  options.rokokol.home = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "user data root: Documents/Pictures/Videos (the myWiki vault lives in $HOME on both hosts)";
    };
  };

  config = {
    home.stateVersion = "25.11";
    programs.home-manager.enable = true;

    xdg.userDirs = {
      enable = true;
      createDirectories = true;
      setSessionVariables = true;

      music = "${myWikiDir}/00. Вложения/02. Music";
      documents = "${cfg.dataDir}/Documents";
      pictures = "${cfg.dataDir}/Pictures";
      videos = "${cfg.dataDir}/Videos";

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
      ]
      ++ lib.optional (cfg.dataDir != homeDir) "file://${cfg.dataDir}/"
      ++ [ "file:///" ];
    };

    # Directories
    systemd.user.tmpfiles.rules = [
      "d ${projectsDir} 0755 - - -"
      "D ${tempDir} 0777 - - -"
    ];

    home.sessionVariables = {
      MY_WIKI = myWikiDir;
    };
  };
}
