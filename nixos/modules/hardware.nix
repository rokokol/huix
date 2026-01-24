{ ... }:

{
  # Enable CUPS to print documents.
  services.printing.enable = true;

  # CPU Governor
  powerManagement.cpuFreqGovernor = "performance";

  # Deepcool hardware support
  services.hardware.deepcool-digital-linux.enable = true;

  # Enable touchpad support
  # services.xserver.libinput.enable = true;

  services.udev.extraRules = ''
    # For the correct work of the Vial
    KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{serial}=="*vial:f64c2b3c*", MODE="0660", TAG+="uaccess", TAG+="udev-acl"

    # Forbidding the sound card to sleep
    ACTION=="add", SUBSYSTEM=="usb", ATTR{idVendor}=="0d8c", ATTR{idProduct}=="0268", ATTR{power/control}="on"
  '';
}

