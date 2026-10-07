_:

{
  # CPU frequency control
  powerManagement.cpuFreqGovernor = "performance";

  # Deepcool hardware support
  services.hardware.deepcool-digital-linux.enable = true;

  # libinput reads the graphics tablet as a touchpad, so it is off on this host
  services.libinput.enable = false;

  services.udev.extraRules = ''
    # Prevent the sound card from going to sleep
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0d8c", ATTR{idProduct}=="0268", ATTR{power/control}="on"
  '';
}
