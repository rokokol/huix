{
  govnoDir,
  pkgs,
  lib,
  rokokolName,
  ...
}:

{
  networking.hostName = "nixos-pc";
  networking.networkmanager.enable = true;

  networking.firewall.trustedInterfaces = [
    "ztu7tmbf2e"
  ];
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [
      80
      6667
      28910
      29900
      29920
    ];
    allowedUDPPorts = [
      4321
      27900
      8088
      9993
    ];

    # Критично для старых игр в Wayland/NixOS:
    checkReversePath = "loose";
  };

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

  # User Configuration
  users.users.${rokokolName} = {
    isNormalUser = true;
    description = "sigma pro";
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

  fileSystems."${govnoDir}" = {
    device = lib.mkForce "/dev/disk/by-label/govno";
    fsType = "ntfs3";
    options = [
      "rw" # Read & Write
      "uid=1000" # rokokol's id
      "gid=100" # rokokol's group id
      "umask=0022" # Access roules (0755 for dirs, 0644 for files)
      "nofail" # Do not break system if fails
      "windows_names" # Do not break ntfs
    ];
  };

  services.xserver.desktopManager.runXdgAutostartIfNone = true;
}
