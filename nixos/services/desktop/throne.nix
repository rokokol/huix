{ pkgs, ... }:

{
  programs.throne = {
    enable = true;
    package = pkgs.throne;
    tunMode.enable = true;
  };

  # TUN replies arrive on throne-tun but their source routes via the LAN link, so strict
  # rpfilter drops every UDP answer (Discord voice)
  networking.firewall.checkReversePath = "loose";
}
