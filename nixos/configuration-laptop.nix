{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./laptop/default.nix
    ./services/services-laptop.nix
  ];

  system.stateVersion = "25.11";
  services.ollama.package = pkgs.ollama-cpu;
}
