{ pkgs, ... }:

{
  home.packages = with pkgs; [
    brightnessctl
    cheese
    powertop
  ];
}
