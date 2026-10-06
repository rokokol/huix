{
  lib,
  pkgs,
  rokokolName,
  ...
}:

# Shared system baseline for every host. The truly host-specific bits
# (hostName, user description) live in nixos/<host>/system.nix; membership
# in groups owned by modules (docker, nvidia, …) stays in those modules
# themselves
{
  programs.zsh.enable = true;

  # Swap compressed in RAM, used only under memory pressure: it holds cold pages in place of an
  # OOM kill. Its priority is above a disk swap's default, so the laptop's partition takes only
  # what zram cannot. A default, so a host can stay without swap
  zramSwap.enable = lib.mkDefault true;

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
      "wheel"
      "video"
      "render"
      "audio"
      "input"
    ];
  };

  # Nix settings
  nix = {
    channel.enable = false;
    settings = {
      experimental-features = [
        "nix-command"
        "flakes"
      ];
      auto-optimise-store = true;
      # Profile links and defexpr live under ~/.local/state/nix rather than as ~/.nix-profile
      # and ~/.nix-defexpr: Home Manager runs nix-env on every activation, which makes them
      use-xdg-base-directories = true;
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
}
