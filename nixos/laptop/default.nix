{ ... }:

{
  imports = [
    ./hardware-configuration.nix
    ./hardware.nix
    ./keyboard.nix
    ./logind.nix
    ./options.nix
    ./system.nix
  ];
}
