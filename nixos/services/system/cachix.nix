{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cachix ];

  # Throne's IPv6 route to Yandex's AS resets the TLS handshake (other IPv6 hosts work fine);
  # pin IPv4 to skip it
  networking.hosts = {
    "213.180.204.183" = [ "mirror.yandex.ru" ];
  };

  nix.settings = {
    fallback = true;

    substituters = [
      "https://cache.nixos.org"
      "https://mirror.yandex.ru/nixos"
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
