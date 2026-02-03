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
    # storageDriver = "overlay2";
    # daemon.settings = {
    #   "bip" = "10.200.0.1/24";
    #   "default-address-pools" = [
    #     { "base" = "10.201.0.0/16"; "size" = 24; }
    #   ];
    # };
  };
}
