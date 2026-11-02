{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./laptop/default.nix
    ./services
  ];

  system.stateVersion = "26.05";
  services.ollama.package = pkgs.ollama-cpu;

  # Linux 6.18.58 and newer never report a lid switch change on this machine, so the lid stops
  # suspending and the lid-mode binds go silent (see WORKAROUNDS.md)
  boot.kernelPackages = pkgs.linuxPackages_6_12;

  rokokol.workstation.enable = true;
  rokokol.sensors.enable = true;
  rokokol.paper-search.enable = false;
  rokokol.syncthing.deviceId = "IACQG6Z-QHUKT7Y-EZXPKTH-BIT3LJR-BCXTRV6-FZZK3LB-SUKSHBR-UG44GAM";

  rokokol.btrfs.mounts = [
    "/"
    "/home"
    "/nix"
  ];
}
