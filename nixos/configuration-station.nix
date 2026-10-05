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
  };
}
