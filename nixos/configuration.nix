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
      ./modules/jupyter.nix
      ./fonts/fonts.nix
    ];

  fileSystems."/home/rokokol/govno" = {
    device = "/dev/disk/by-uuid/014B8F2D5325F68F";
    fsType = "ntfs-3g";
    options = [
      "rw" # Read & Write
      "uid=1000" # rokokol's id
      "gid=100" # rokokol's group id
      "umask=0022" # Access roules (0755 for dirs, 0644 for files)
      "nofail" # Do not break system if fails
    ];
  };

  #System status version (not to be changed unnecessarily requested)
  system.stateVersion = "25.11";
}

