{
  config,
  lib,
  huixDir,
  myWikiDir,
  projectsDir,
  rokokolName,
  ...
}:

let
  homeDir = "/home/${rokokolName}";
  downloadsDir = "${homeDir}/Downloads";
  tempDir = "/tmp/Temp";
in
{
  imports = [
    ./hyprland/hyprland.nix
    ./packages/packages.nix
    ./sync.nix
    ./theme/default.nix
  ];

  # The one list of bookmarks: Thunar's side pane reads it through GTK, and yazi binds each key
  # after `g`
  options.rokokol.bookmarks = lib.mkOption {
    type = lib.types.listOf (
      lib.types.submodule {
        options = {
          key = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "the key after `g` in yazi, none for a folder yazi already has one for";
          };
          path = lib.mkOption {
            type = lib.types.str;
            description = "the folder";
          };
        };
      }
    );
    description = "folders to bookmark, in the order the side pane lists them";
  };

  config = {
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

    # yazi's own `g d` goes to ~/Downloads
    rokokol.bookmarks = [
      { path = downloadsDir; }
      {
        key = "u";
        path = huixDir;
      }
      {
        key = "e";
        path = tempDir;
      }
      {
        key = "p";
        path = projectsDir;
      }
      {
        key = "w";
        path = myWikiDir;
      }
      {
        key = "/";
        path = "/";
      }
    ];

    gtk = {
      enable = true;
      gtk3.bookmarks = map (b: "file://${lib.removeSuffix "/" b.path}/") config.rokokol.bookmarks;
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
