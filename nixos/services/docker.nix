{ pkgs, ... }:

{
  virtualisation.docker = {
    enable = true;
    rootless = {
      enable = true;
      setSocketVariable = true; # To help docker find my socket without root
    };

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
