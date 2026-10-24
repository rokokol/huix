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
  # PaperQA's local models are too slow without a GPU
  rokokol.paper-search.enable = false;
  rokokol.syncthing.deviceId = "IACQG6Z-QHUKT7Y-EZXPKTH-BIT3LJR-BCXTRV6-FZZK3LB-SUKSHBR-UG44GAM";

  rokokol.btrfs.mounts = [
    "/"
    "/home"
    "/nix"
  ];
}
