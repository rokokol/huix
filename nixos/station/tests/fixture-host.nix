{ fixtures, stationMac }:
# What a VM cannot have of the station, replaced in every test that runs it: the card's MAC,
# smartd, and the secrets, which come from the fixtures. How the age key gets there is each
# test's own question
{ lib, ... }:
{
  systemd.network.networks."10-lan".matchConfig.PermanentMACAddress = lib.mkForce stationMac;

  sops.defaultSopsFile = lib.mkForce "${fixtures}/station.yaml";
  # Validation reads the file at evaluation, which would build the fixtures under
  # `nix flake check`. The host keeps it, and a VM decrypts every secret anyway
  sops.validateSopsFiles = false;

  # A virtual disk has no SMART data, and smartd fails with no device to watch
  services.smartd.enable = lib.mkForce false;
}
