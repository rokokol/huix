{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [ cachix ];

  # The tunnel's IPv6 route to Yandex's AS resets the TLS handshake (other IPv6 hosts work
  # fine); pin IPv4 to skip it
  networking.hosts = {
    "213.180.204.183" = [ "mirror.yandex.ru" ];
  };

  nix.settings = {
    fallback = true;

    # The Hyprland cache holds the main-branch compositor the flake input brings in on both
    # hosts (see DEVIATIONS.md for why that input keeps its own nixpkgs)
    substituters = [
      "https://cache.nixos.org"
      "https://mirror.yandex.ru/nixos"
      "https://nix-community.cachix.org"
      "https://hyprland.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
      "hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="
    ];
  };
}
