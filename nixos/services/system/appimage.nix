{ pkgs, ... }:

# Run foreign binaries the "just works" way, two complementary tools:
#
#   * programs.appimage.binfmt — registers a binfmt_misc handler so you can run
#     any *.AppImage directly (./Foo.AppImage), no chmod-and-pray, no extractor.
#     This is the typical workshop/master-class delivery format.
#
#   * steam-run — wraps an arbitrary command in a full FHS sandbox (real /usr,
#     /lib, ld.so). When ./appimage.nix's nix-ld baseline is not enough for a
#     stubborn prebuilt binary: `steam-run ./installer` and it behaves like a
#     normal distro. The heavier hammer; reach for it second.

{
  programs.appimage = {
    enable = true;
    binfmt = true; # double-click / ./Foo.AppImage runs directly
  };

  environment.systemPackages = with pkgs; [
    steam-run # `steam-run <cmd>`: FHS sandbox for any prebuilt binary
  ];
}
