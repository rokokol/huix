{ ... }:

{
  imports = [
    ./fonts/fonts.nix
    ./pc/hardware-configuration.nix
    ./pc/boot.nix
    ./pc/nvidia.nix
    ./pc/system.nix
    ./pc/hardware.nix
    ./pc/sound.nix
    ./pc/desktop.nix
    ./pc/packages.nix
    ./services/docker.nix
    ./services/jupyter.nix
    ./services/searxng.nix
  ];

  system.stateVersion = "25.11";
}
