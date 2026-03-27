{ ... }:

{
  boot = {
    kernelParams = [ "snd_hda_intel.model=auto" ];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };

    tmp = {
      useTmpfs = true;
      tmpfsSize = "50G";
    };
  };
}
