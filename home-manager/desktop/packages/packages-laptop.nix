{ pkgs, ... }:

{
  imports = [ ./packages-common.nix ];

  home.packages = with pkgs; [
    brightnessctl
    cheese
    powertop
  ];
}
