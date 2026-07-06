{ pkgs, rokokolName, ... }:

# Shared system baseline for both hosts. Genuinely host-specific bits
# (hostName, user description, the govno mount) stay in nixos/<host>/system.nix;
# module-owned group memberships (docker, nvidia, …) stay in their own modules.
{
  networking.networkmanager.enable = true;

  # Time and Locale
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

  # User Configuration (base; description is set per-host, extra groups are
  # merged in from the modules that own them — docker.nix, nvidia.nix, …)
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

  # Nix Settings
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
