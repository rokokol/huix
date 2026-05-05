{ ... }:

{
  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # --- Other ___
  powerManagement.powertop.enable = true;
  nixpkgs.config.allowUnfree = true;
}
