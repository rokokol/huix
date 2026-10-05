{ ... }:

{
  imports = [
    ./alerts.nix
    ./boot.nix
    ./disko.nix
    ./hardware-configuration.nix
    ./network.nix
    ./sops.nix
    ./system.nix
    ./wake-pc.nix
  ];
}
