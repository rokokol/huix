{ pkgs, ... }:

{
  programs.nix-ld.enable = true;
  programs.nix-ld.libraries = with pkgs; [
    # MATLAB
    linux-pam
    stdenv.cc.cc
    glib
    zlib
    libxcrypt
    freetype
    dbus
    fontconfig
    libGL
    nss
    nspr
    alsa-lib
  ];
}
