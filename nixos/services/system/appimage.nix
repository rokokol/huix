{ pkgs, ... }:

# Running foreign binaries "so they just work", two complementary tools:
#
#   * programs.appimage.binfmt — registers a binfmt_misc handler so any
#     *.AppImage runs directly (./Foo.AppImage), without chmod-and-pray and
#     unpacking. A typical distribution format at workshops/masterclasses
#
#   * steam-run — wraps an arbitrary command in a full FHS sandbox (real /usr,
#     /lib, ld.so). When the nix-ld base from ./nix-ld.nix isn't enough for a
#     stubborn prebuilt: `steam-run ./installer` — and it behaves as on a
#     regular distro. A heavier hammer; reach for it second

{
  programs.appimage = {
    enable = true;
    binfmt = true; # double-click / ./Foo.AppImage runs directly
  };

  environment.systemPackages = with pkgs; [
    steam-run # `steam-run <cmd>`: FHS sandbox for any prebuilt binary
  ];
}
