{ config, pkgs, ... }:

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
      snapshotDir = "${backup}/snapshots/restic";
    };
    radicale = {
      enable = true;
      mountPoint = backup;
      dataDir = "${backup}/radicale";
      snapshotDir = "${backup}/snapshots/radicale";
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
    mya-agent = {
      enable = true;
      git.email = "mya@rokokol.art";
      packages = with pkgs; [ ffmpeg ];
      pythonPackages = ps: [ ps.matplotlib ];
      # Topics of the owner's chat with the bot
      hermes.homeTopic = 1089068;
      hermes.cronTopic = 1089660;
      hermes.reportsTopic = 1089071;
      # About 200 MB at rest, measured in the station test VM
      hermes.dashboardAutoStart = true;
      hermes.backup = {
        mountPoint = backup;
        dataDir = "${backup}/hermes";
        snapshotDir = "${backup}/snapshots/hermes";
      };
    };

    mail-agent = {
      enable = true;
      socketUser = config.rokokol.mya-agent.user;
    };
    printer.client = {
      enable = true;
      prepareCommand = [ "wake-pc" ];
    };
    telegram-agent = {
      enable = true;
      socketUser = config.rokokol.mya-agent.user;
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
