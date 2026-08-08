{ inputs, ... }:

{
  imports = [
    ./cli/default.nix
    ./nixvim/default.nix
    ./rofi/default.nix
    # Lives next to the scripts it wraps, so reach it from the flake root rather than by ../..
    # No builtins.path here: an import is read at eval time and never becomes a derivation input,
    # so it can't tie a hash to the whole repo the way a src = "${inputs.self}/..." would
    "${inputs.self}/scripts/scripts.nix"
    ./term/default.nix
    ./thunar.nix
    ./zen.nix
  ];
}
