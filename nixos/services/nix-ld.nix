{ pkgs, ... }:

{
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    # MATLAB
    stdenv.cc.cc
    zlib
    glib
  ];
}
