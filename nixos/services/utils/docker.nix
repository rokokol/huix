{
  config,
  lib,
  rokokolName,
  ...
}:

{
  options.rokokol.docker.enable = lib.mkEnableOption "the Docker daemon" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.docker.enable {
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

    users.users.${rokokolName} = {
      extraGroups = [ "docker" ];
    };
  };
}
