{ pkgs, inputs, ... }:

{
  programs.home-manager.enable = true;
  imports = [
    ./desktop/user-pc.nix
    ./programs/default.nix
  ];

  _module.args.btopPackage = pkgs.btop-cuda;
}
