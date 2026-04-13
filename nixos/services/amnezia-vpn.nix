{ pkgs, ... }:

{
  programs.amnezia-vpn = {
    enable = true;
    package = pkgs.stable.amnezia-vpn;
  };
}
