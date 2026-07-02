{ config, lib, ... }:

{
  options.custom.tablet.enable = lib.mkEnableOption "графический планшет (OpenTabletDriver)";

  config = lib.mkIf config.custom.tablet.enable {
    hardware.opentabletdriver = {
      enable = true;
      daemon.enable = true;
    };

    boot.kernelModules = [ "uinput" ];
    boot.blacklistedKernelModules = [ "hid-uclogic" ];

    # Скрыть ЛЮБОЙ физический графический планшет от libinput/Hyprland: курсором
    # рулит только виртуальный девайс OpenTabletDriver. Иначе багает
    services.udev.extraRules = ''
      SUBSYSTEM=="input", ENV{ID_INPUT_TABLET}=="1", ENV{ID_BUS}=="usb", ENV{LIBINPUT_IGNORE_DEVICE}="1"
      SUBSYSTEM=="input", ENV{ID_INPUT_KEYBOARD}=="1", ENV{ID_VENDOR_ID}=="256c", ENV{ID_MODEL_ID}=="006d", ENV{LIBINPUT_IGNORE_DEVICE}="1"
    '';
  };
}
