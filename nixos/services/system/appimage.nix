{ pkgs, ... }:

# binfmt_misc lets *.AppImage run directly without unpacking
# steam-run wraps any binary in a full FHS sandbox (/usr, /lib, real ld.so) for prebuilts that nix-ld can't satisfy

{
  programs.appimage = {
    enable = true;
    binfmt = true; # double-click / ./Foo.AppImage runs directly
  };

  environment.systemPackages = with pkgs; [
    steam-run # `steam-run <cmd>`: FHS sandbox for any prebuilt binary
  ];
}
