{ config, lib, ... }:

# Unlocks the GeForce FP16/BF16/TF32 tensor cap. It works only from the initrd, before the driver
# binds a card, so the service below orders it; the mechanism is in nixpkgs' cuda.section.md
let
  cfg = config.rokokol.gpu-unlock;
in
{
  options.rokokol.gpu-unlock = {
    enable = lib.mkEnableOption "the GeForce tensor core unlock";

    targets = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ "all" ];
      description = ''
        Cards to unlock, as "all" or as full PCI names that lspci -D prints. A card that is not
        supported is logged and skipped
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    boot.extraModulePackages = [ config.boot.kernelPackages.gpu-unlock ];
    hardware.firmware = [ config.boot.kernelPackages.gpu-unlock.firmware ];
    boot.initrd.availableKernelModules = [ "gpu_unlock" ];
    boot.kernelParams = [ "gpu_unlock.targets=${lib.concatStringsSep "," cfg.targets}" ];

    boot.initrd.systemd.services.gpu-unlock = {
      description = "Unlock NVIDIA GPU tensor core throughput";
      wantedBy = [ "sysinit.target" ];
      before = [
        "sysinit.target"
        "systemd-modules-load.service"
        "systemd-udevd.service"
        "systemd-udev-trigger.service"
      ];
      unitConfig.DefaultDependencies = false;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = "/bin/modprobe gpu_unlock";
      };
    };
  };
}
