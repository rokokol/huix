{ pkgs, ... }:

{
  programs.amnezia-vpn = {
    enable = true;
    package = pkgs.amnezia-vpn;
  };
}
