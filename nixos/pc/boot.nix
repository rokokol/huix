{ pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages_latest;
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50G";
    };
  };
}
