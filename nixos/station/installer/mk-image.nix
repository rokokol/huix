{ inputs, system, ... }@commonArgs:
# The installer image as a NixOS system, for the one system it installs. The flake builds it for
# nixos-station and the install test for a variant with fixture secrets, so both run the same
# image; `modules` adds what only the test needs
{
  target,
  modules ? [ ],
}:
inputs.nixpkgs.lib.nixosSystem {
  specialArgs = commonArgs;
  modules = [
    ./iso.nix
    {
      nixpkgs.hostPlatform = system;
      rokokol.station-installer.target = target;
    }
  ]
  ++ modules;
}
