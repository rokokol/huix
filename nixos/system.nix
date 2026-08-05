{ pkgs, rokokolName, ... }:

# Shared system baseline for both hosts. The truly host-specific bits
# (hostName, user description, govno mounting) live in
# nixos/<host>/system.nix; membership in groups owned by modules
# (docker, nvidia, …) stays in those modules themselves
{
  networking.networkmanager.enable = true;

  # Time and locale
  time.timeZone = "Europe/Moscow";
  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ru_RU.UTF-8";
    LC_IDENTIFICATION = "ru_RU.UTF-8";
    LC_MEASUREMENT = "ru_RU.UTF-8";
    LC_MONETARY = "ru_RU.UTF-8";
    LC_NAME = "ru_RU.UTF-8";
    LC_NUMERIC = "ru_RU.UTF-8";
    LC_PAPER = "ru_RU.UTF-8";
    LC_TELEPHONE = "ru_RU.UTF-8";
    LC_TIME = "ru_RU.UTF-8";
  };

  # User (base; description is set per-host, extra groups are mixed in
  # from the modules that own them — docker.nix, nvidia.nix, …)
  users.users.${rokokolName} = {
    isNormalUser = true;
    home = "/home/${rokokolName}";
    shell = pkgs.zsh;
    extraGroups = [
      "networkmanager"
      "wheel"
      "video"
      "render"
      "audio"
      "input"
    ];
  };

  # Nix settings
  nix = {
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      trusted-users = [
        "root"
        "@wheel"
      ];
    };
    gc = {
      automatic = true;
      dates = "daily";
      options = "--delete-older-than 7d";
    };
  };

  services.xserver.desktopManager.runXdgAutostartIfNone = true;
}
