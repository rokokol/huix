{ pkgs, ... }:

{
  programs.throne = {
    enable = true;
    package = pkgs.throne;
    tunMode.enable = true;
  };
}
