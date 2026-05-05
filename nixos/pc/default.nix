{ ... }:

{
  imports = [
    ./boot.nix
    ./hardware-configuration.nix
    ./hardware.nix
    ./keyboard.nix
    ./nvidia.nix
    ./options.nix
    ./system.nix
  ];
}
