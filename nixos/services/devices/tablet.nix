{ pkgs, ... }:

{
  hardware.opentabletdriver = {
    enable = true;
    daemon.enable = true;
  };

  boot.kernelModules = [ "uinput" ];
  boot.blacklistedKernelModules = [ "hid-uclogic" ];

  # Скрыть сырой планшет GAOMON S630 (256c:006d) от libinput/Hyprland: курсором
  # рулит только виртуальный девайс OpenTabletDriver. Иначе сырой планшет летит
  # как mouse0 и дерётся с OTD за абсолютную позицию — курсор залипает, обычная
  # мышь перестаёт работать, клики пером пропадают. OTD читает планшет напрямую
  # через hidraw/usb, поэтому продолжает работать.
  services.udev.extraRules = ''
    SUBSYSTEM=="input", ATTRS{idVendor}=="256c", ATTRS{idProduct}=="006d", ENV{LIBINPUT_IGNORE_DEVICE}="1"
  '';
}
