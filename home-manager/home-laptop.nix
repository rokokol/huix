{ pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;
  imports = [
  inputs.nixvim.homeModules.nixvim
  ./programs/nixvim/default.nix
    ./desktop/user-laptop.nix
    ./programs/default.nix
  ];

  _module.args.btopPackage = pkgs.btop;
}
