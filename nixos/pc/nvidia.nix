{ pkgs, ... }:

{
  # OpenGL on (Hardware Graphics)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;

    # Stable kernel
    package = pkgs.stable.linuxPackages_latest.nvidiaPackages.stable;
  };
}
