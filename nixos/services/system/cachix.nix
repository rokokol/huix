{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cachix ];

  nix.settings = {
    # connect-timeout = 4;
    # fallback = true;
    # stalled-download-timeout = 4;

    substituters = [
      "https://cache.nixos.org"
      "https://cache.nixos.kz"
      "https://mirror.yandex.ru/nixos"
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
