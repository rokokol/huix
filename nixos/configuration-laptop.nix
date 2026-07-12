{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./laptop/default.nix
    ./services
  ];

  system.stateVersion = "25.11";
  services.ollama.package = pkgs.ollama-cpu;

  custom = {
    jupyter.enable = true;
    meshtastic.enable = true;
  };
}
