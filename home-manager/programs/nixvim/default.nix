{ inputs, ... }:

{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./settings.nix
    ./keymaps.nix
    ./plugins/default.nix
    ./packages.nix
  ];
}
