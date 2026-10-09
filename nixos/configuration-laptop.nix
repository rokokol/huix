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

  rokokol.btrfs.mounts = [
    "/"
    "/home"
    "/nix"
  ];
}
