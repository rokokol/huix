{ pkgs, ... }:

{
  # --- Core desktop session ---
  programs.zsh.enable = true;
  programs.hyprland.enable = true;

  # --- Bluetooth ---
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;
  services.blueman.enable = true;

  # --- Gaming & power ---
  programs.steam.enable = true;
  powerManagement.powertop.enable = true;

  nixpkgs.config.allowUnfree = true;
}
