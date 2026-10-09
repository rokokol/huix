{
  pkgs,
  inputs,
  rokokolName,
  ...
}:

{
  imports = [
    ./default.nix
    ./pc/default.nix
    ./services
  ];

  system.stateVersion = "25.11";
  services.ollama.package = pkgs.stable.ollama-cuda;
  # The owner keeps this host without swap of any kind
  zramSwap.enable = false;

  services.virtual-media-devices.camera = {
    enable = true;
    users = [ rokokolName ];
  };

  rokokol = {
    workstation.enable = true;

    btrfs.mounts = [
      "/"
      "/home"
    ];

    searxng.enable = false;
    telegram-agent.enable = true;

    printer.enable = true;
    tablet.enable = true;
    virtualization.enable = true;

    # The CI of the station's Forgejo; the station lists this host in rokokol.forgejo.runners
    forgejo-runner = {
      enable = true;
      url =
        inputs.self.nixosConfigurations.nixos-station.config.services.forgejo.settings.server.ROOT_URL;
    };
  };
}
