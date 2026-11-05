{ fixtures, stationMac }:
# What a VM cannot have of the station, replaced in every test that runs it: the card's MAC,
# smartd, and the secrets, which come from the fixtures. How the age key gets there is each
# test's own question
{ lib, pkgs, ... }:
{
  systemd.network.links."10-lan".matchConfig.PermanentMACAddress = lib.mkForce stationMac;
  systemd.network.networks."10-lan".matchConfig.PermanentMACAddress = lib.mkForce stationMac;

  sops.defaultSopsFile = lib.mkForce "${fixtures}/station.yaml";
  sops.secrets.hindsight-api-token.sopsFile = lib.mkForce "${fixtures}/station.yaml";
  sops.secrets.hindsight-client-token.sopsFile = lib.mkForce "${fixtures}/station.yaml";
  sops.secrets.mail-agent.sopsFile = lib.mkForce "${fixtures}/mail-agent.yaml";
  sops.secrets.drive-backup-client.sopsFile = lib.mkForce "${fixtures}/drive-backup.json";
  sops.secrets.telegram-api-id.sopsFile = lib.mkForce "${fixtures}/telegram-agent.yaml";
  sops.secrets.telegram-api-hash.sopsFile = lib.mkForce "${fixtures}/telegram-agent.yaml";
  # Validation reads the file at evaluation, which would build the fixtures under
  # `nix flake check`. The host keeps it, and a VM decrypts every secret anyway
  sops.validateSopsFiles = false;

  # The local backend tests real transfers and hashes without a Google account
  rokokol.drive-backup.cloud.destination = "fixture:/var/lib/restic-cloud/mirror";
  systemd.timers.restic-cloud.wantedBy = lib.mkForce [ ];
  systemd.timers.restic-cloud-heartbeat.wantedBy = lib.mkForce [ ];
  systemd.services.restic-cloud.preStart = lib.mkBefore ''
    install -m 0600 ${pkgs.writeText "rclone-fixture.conf" "[fixture]\ntype = local\n"} /var/lib/restic-cloud/rclone.conf
  '';

  # A virtual disk has no SMART data, and smartd fails with no device to watch
  services.smartd.enable = lib.mkForce false;
}
