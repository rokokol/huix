{ ... }:

{
  imports = [
    ./desktop/user.nix
    ./programs/default.nix
  ];

  # The archive and the backups live here, so a video is compressed where it already lies
  rokokol.compress-video.enable = true;
}
