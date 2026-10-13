{ pkgs, ... }:

let
  backup = "/srv/backup";
in
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
      mountPoint = backup;
      dataDir = "${backup}/restic";
    };
    syncthing = {
      # Made by the station's Syncthing at its first start; its key in sops keeps it
      deviceId = "6CQJLFE-TE77FII-NTQQIOX-XKDOALI-WFDZU4D-SJLMJ62-MUMN5S4-KSPMJQV";
      archive = {
        enable = true;
        mountPoint = backup;
        dir = "${backup}/syncthing";
        snapshotDir = "${backup}/snapshots/syncthing";
      };
    };

    # Edits the archive's folders, so Syncthing runs as its user and sends the changes
    claude-agent = {
      enable = true;
      packages = with pkgs; [ ffmpeg ];
    };

    backup-heartbeat.enable = true;
    alert-mail.enable = true;
    prometheus.enable = true;
    grafana.enable = true;
    pushgateway.enable = true;
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
