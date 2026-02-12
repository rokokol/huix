{ pkgs, ... }:

{
  hardware.opentabletdriver = {
    enable = true;
    daemon.enable = true;
  };

  boot.kernelModules = [ "uinput" ];
  boot.blacklistedKernelModules = [ "hid-uclogic" ];
}
