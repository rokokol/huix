{ pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.linuxPackages;
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50G";
    };
  };
}
