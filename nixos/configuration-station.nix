_:

{
  imports = [
    ./default.nix
    ./station/default.nix
    ./services
  ];

  system.stateVersion = "26.11";

  rokokol = {
    restic-server = {
      enable = true;
      mountPoint = "/srv/backup";
      dataDir = "/srv/backup/restic";
    };

    backup-heartbeat.enable = true;
    alert-mail.enable = true;
    forgejo.enable = true;
    forgejo-mirrors = {
      enable = true;
      forks = [ "obsidian-media-gallery" ];
      exclude = [ "myWiki_real" ];
    };
  };
}
