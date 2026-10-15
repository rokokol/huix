{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./laptop/default.nix
    ./services
  ];

  system.stateVersion = "26.05";
  services.ollama.package = pkgs.ollama-cpu;

  rokokol.workstation.enable = true;
  rokokol.sensors.enable = true;
  rokokol.syncthing.deviceId = "IACQG6Z-QHUKT7Y-EZXPKTH-BIT3LJR-BCXTRV6-FZZK3LB-SUKSHBR-UG44GAM";

  rokokol.btrfs.mounts = [
    "/"
    "/home"
    "/nix"
  ];
}
