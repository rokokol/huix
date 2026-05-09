{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.cachix ];

  nix.settings = {
    connect-timeout = 4;
    stalled-download-timeout = 4;
    fallback = true;

    substituters = [
      "https://cache.nixos.org"
      "https://mirror.yandex.ru/nixos"
      "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store"
      "https://nixos-cache-proxy.cofob.dev"
      "https://nixos-cache-proxy.sweetdogs.ru"
      "https://ncproxy.vizqq.cc"
      "https://nix-community.cachix.org"
    ];

    trusted-public-keys = [
      "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
      "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    ];
  };
}
