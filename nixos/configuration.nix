{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./fonts/fonts.nix
    ./computer/boot.nix
    ./computer/nvidia.nix
    ./computer/system.nix
    ./computer/hardware.nix
    ./computer/sound.nix
    ./services/docker.nix
    ./services/jupyter.nix
    ./services/searxng.nix
    ./software/nix-ld.nix
    ./software/desktop.nix
    ./software/packages.nix
  ];

  #System status version (not to be changed unnecessarily requested)
  system.stateVersion = "25.11";
}
