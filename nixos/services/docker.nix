{ ... }:

{
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
    };
  };

  users.users.rokokol = {
    extraGroups = [
      "docker"
    ];
  };
}
