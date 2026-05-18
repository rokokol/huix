{ pkgs, ... }:

{
  programs.nix-ld.enable = true;

  programs.nix-ld.libraries = with pkgs; [
    # MATLAB
    stdenv.cc.cc
    stdenv.cc.cc.lib
    linuxPackages.nvidia_x11
    libGL
    glib
    zlib
    glib
    pam
  ];
}
