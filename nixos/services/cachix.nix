{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cachix ];

  nix.settings = {
    substituters = [
      "https://cache.nixos.org"
      "https://cuda-maintainers.cachix.org"
    ];
    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "cuda-maintainers.cachix.org-1:0dq3bujKpuEPM97uXNo7Cqyf66IuU8Hk2oG0g8v8p6s="
    ];
  };
}
