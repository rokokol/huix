{ pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;
  imports = [
    ./desktop/user-laptop.nix
    ./programs/default.nix
  ];

  _module.args.btopPackage = pkgs.btop;
}
