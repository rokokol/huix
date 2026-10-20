{
  config,
  lib,
  rokokolName,
  ...
}:

{
  # OpenGL (hardware graphics)
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  boot.kernelParams = [ "nvidia_drm.fbdev=1" ];

  # off by default in the driver; without it BAR1 stays 256 MiB and every GL-on-Vulkan
  # client (zink) is capped by that, not by VRAM. Needs Above 4G Decoding + Re-Size BAR
  # in the BIOS — check with: nvidia-smi -q | grep -A3 "BAR1 Memory Usage"
  boot.extraModprobeConfig = "options nvidia NVreg_EnableResizableBar=1";

  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;

    package = config.boot.kernelPackages.nvidiaPackages.production;
  };
  hardware.nvidia-container-toolkit.enable = true;

  # Load, memory, temperature and power of the GPU for the station's Prometheus, read through
  # nvidia-smi of the driver above. It listens as nixos/services/system/monitoring/node-exporter.nix does
  services.prometheus.exporters.nvidia-gpu.enable = true;

  # nix-ld needs the userspace of exactly the driver installed on this host; the
  # shared list in nixos/services/system/nix-ld.nix stays GPU-agnostic
  programs.nix-ld.libraries = [ config.hardware.nvidia.package ];

  # A Flatpak app loads the driver's userspace from a Flathub extension built for one driver
  # version, and only the one that matches the kernel module works. With the version taken from
  # the package above, a driver update installs its extension in the same switch, and nix-flatpak
  # removes the old one. 1.4 is the branch of the extension point the freedesktop runtimes load
  services.flatpak.packages = lib.mkIf config.services.flatpak.enable (
    map
      (
        gl:
        "org.freedesktop.Platform.${gl}.nvidia-${
          lib.replaceStrings [ "." ] [ "-" ] config.hardware.nvidia.package.version
        }/x86_64/1.4"
      )
      [
        "GL"
        "GL32"
      ]
  );

  users.users.${rokokolName} = {
    extraGroups = [
      "video"
      "render"
    ];
  };

  # btop-cuda and the cudaPackages closure come from here, because cache.nixos.org builds no
  # unfree package. ollama-cuda does not: cudaCapabilities moves its hash out of every cache
  nix.settings = {
    substituters = [ "https://cache.nixos-cuda.org" ];

    trusted-public-keys = [
      "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M="
    ];
  };
}
