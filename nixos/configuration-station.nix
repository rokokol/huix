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
    prometheus.enable = true;
    grafana.enable = true;
    forgejo = {
      enable = true;
      # The PC runs the CI jobs, through rokokol.forgejo-runner
      runners = [ "nixos-pc" ];
    };
    forgejo-mirrors = {
      enable = true;
      forks = [ "obsidian-media-gallery" ];
      exclude = [ "myWiki_real" ];
    };
  };
}
