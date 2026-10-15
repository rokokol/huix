{ ... }:

{
  imports = [
    ./agent-guest.nix
    ./core-options.nix
    ./portals.nix
    ./logind.nix
  ];
}
