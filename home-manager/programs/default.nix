{ inputs, ... }:

{
  imports = [
    ./cli/default.nix
    ./nixvim/default.nix
    ./rofi/default.nix
    # Lives next to the scripts it wraps, so reach it from the flake root rather than by ../..
    "${inputs.self}/scripts/scripts.nix"
    ./term/default.nix
    ./thunar.nix
    ./zen.nix
  ];
}
