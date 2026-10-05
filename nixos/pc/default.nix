{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./keyboard.nix
    ./nvidia.nix
    ./options.nix
    ./system.nix
    ./wake-on-lan.nix
  ];
}
