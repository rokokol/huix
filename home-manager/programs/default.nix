{ inputs, ... }:

{
  imports = [
    ./cli/default.nix
    ./nixvim/default.nix
    ./rofi.nix
    "${inputs.self}/scripts/scripts.nix"
    ./term/default.nix
    ./thunar.nix
    ./virtual-mic.nix
    ./zen.nix
  ];
}
