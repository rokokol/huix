{ config, rokokolName, ... }:

{
  # OpenGL (аппаратная графика)
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

    # Стабильное ядро
    package = config.boot.kernelPackages.nvidiaPackages.latest;
  };
  hardware.nvidia-container-toolkit.enable = true;

  # nix-ld нужен userspace ровно того драйвера, что стоит на этом хосте; общий
  # список в nixos/services/system/nix-ld.nix остаётся GPU-агностичным.
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
