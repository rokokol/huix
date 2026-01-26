{ config, pkgs, pkgs-stable, inputs, ... }:

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
      ./modules/nix-ld.nix
      ./fonts/fonts.nix
    ];

  #System status version (not to be changed unnecessarily requested)
  system.stateVersion = "25.11";
}

