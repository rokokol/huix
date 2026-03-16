{ ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };

    daemon.settings = {
      default-address-pools = [
        {
          base = "10.10.0.0/16";
          size = 24;
        }
      ];
    };
  };

  users.users.rokokol = {
    extraGroups = [
      "docker"
    ];
  };
}
