{ inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./clipboard.nix
    ./settings.nix
    ./keymaps.nix
    ./plugins/default.nix
    ./packages.nix
    ./opener.nix
  ];
}
