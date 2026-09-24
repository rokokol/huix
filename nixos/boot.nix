{ lib, ... }:

{
  boot = {
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    tmp = {
      useTmpfs = lib.mkDefault true;
      tmpfsSize = "50G";
    };
  };
}
