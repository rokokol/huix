{ ... }:

{
  # CPU frequency control
  powerManagement.cpuFreqGovernor = "performance";

  # Deepcool hardware support
  services.hardware.deepcool-digital-linux.enable = true;

  # libinput reads the graphics tablet as a touchpad, so it is off on this host
  services.libinput.enable = false;

  services.udev.extraRules = ''
    # For Vial to work correctly
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", TAG+="uaccess", TAG+="udev-acl"

    # Prevent the sound card from going to sleep
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0d8c", ATTR{idProduct}=="0268", ATTR{power/control}="on"
  '';
}
