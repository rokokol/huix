{ pkgs, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    kernelPackages = pkgs.stable.linuxPackages;
    tmp = {
      useTmpfs = true;
      tmpfsSize = "50G";
    };
  };
}
