{
  config,
  lib,
  huixDir,
  rokokolName,
  ...
}:

let
  cfg = config.custom.home;
  homeDir = "/home/${rokokolName}";
  myWikiDir = "${cfg.dataDir}/myWiki";
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

  options.custom.home = {
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "база пользовательских данных: Documents/Pictures/Videos и myWiki";
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
