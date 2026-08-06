{ config, rokokolName, ... }:

{
  # OpenGL (hardware graphics)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;

    # Production branch, not latest: stay off the 610 new-feature branch, keep the well-tested driver line
    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
  hardware.nvidia-container-toolkit.enable = true;

  # nix-ld needs the userspace of exactly the driver installed on this host; the
  # shared list in nixos/services/system/nix-ld.nix stays GPU-agnostic
  programs.nix-ld.libraries = [ config.hardware.nvidia.package ];

  users.users.${rokokolName} = {
    extraGroups = [
      "video"
      "render"
    ];
  };

  nix.settings = {
    substituters = [
      "https://cuda-maintainers.cachix.org"
    ];

    trusted-public-keys = [
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPMCX6U4WylrUDZ9JyUG0VpVZa7CNfq5E="
    ];
  };
}
