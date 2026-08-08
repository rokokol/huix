{ inputs, ... }:

{
  imports = [
    ./cli/default.nix
    ./nixvim/default.nix
    ./rofi/default.nix
    "${inputs.self}/scripts/scripts.nix"
    ./term/default.nix
    ./thunar.nix
    ./zen.nix
  ];
}
