{ pkgs, ... }:

{
  imports = [
    ./default.nix
    ./pc/default.nix
    ./services/services-pc.nix
  ];

  system.stateVersion = "25.11";
  services.ollama.package = pkgs.ollama-cuda;
}
