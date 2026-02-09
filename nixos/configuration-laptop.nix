{ ... }:

{
  imports = [
    ./fonts/fonts.nix
    ./laptop/hardware-configuration.nix
    ./laptop/boot.nix
    ./laptop/desktop.nix
    ./laptop/hardware.nix
    ./laptop/packages.nix
    ./laptop/system.nix
    ./services/wl-clip-persist.nix
    ./services/sddm.nix
  ];

  system.stateVersion = "25.11";
}
