{ pkgs, ... }:

{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Newest kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;
  # boot.kernelParams = [ "usbcore.autosuspend=-1" ];
}

