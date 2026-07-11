{ ... }:

{
  # Управление частотой CPU
  powerManagement.cpuFreqGovernor = "performance";

  # Поддержка железа Deepcool
  services.hardware.deepcool-digital-linux.enable = true;

  # Поддержка тачпада; выключить ради графического планшета
  # services.xserver.libinput.enable = true;

  services.udev.extraRules = ''
    # Для корректной работы Vial
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", TAG+="uaccess", TAG+="udev-acl"

    # Запрещаем звуковой карте засыпать
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0d8c", ATTR{idProduct}=="0268", ATTR{power/control}="on"
  '';
}
