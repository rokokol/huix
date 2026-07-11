{ pkgs, rokokolName, ... }:

# Общий системный базис для обоих хостов. По-настоящему хост-специфичное
# (hostName, описание пользователя, монтирование govno) лежит в
# nixos/<host>/system.nix; членство в группах, которым владеют модули
# (docker, nvidia, …), остаётся в самих этих модулях.
{
  networking.networkmanager.enable = true;

  # Время и локаль
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

  # Пользователь (база; описание задаётся per-host, доп. группы домешиваются
  # из модулей, которым они принадлежат — docker.nix, nvidia.nix, …)
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

  # Настройки Nix
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
