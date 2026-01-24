{ config, pkgs, pkgs-stable, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
      ./modules/boot.nix
      ./modules/nvidia.nix
      ./modules/desktop.nix
      ./modules/sound.nix
      ./modules/packages.nix
      ./modules/hardware.nix
      ./modules/system.nix
    ];

  #System status version (not to be changed unnecessarily requested)
  system.stateVersion = "25.11";
}

