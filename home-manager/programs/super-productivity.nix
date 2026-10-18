{
  config,
  lib,
  pkgs,
  ...
}:

# Super Productivity on the desktop, started with the graphical session. The station runs its
# own copy with no screen: nixos/services/tools/super-productivity.nix
{
  options.rokokol.super-productivity.enable =
    lib.mkEnableOption "Super Productivity, started with the graphical session"
    // {
      default = config.rokokol.workstation.enable;
    };

  config = lib.mkIf config.rokokol.super-productivity.enable {
    home.packages = with pkgs; [ super-productivity ];

    # Quitting the app is the owner's choice, so it is not started again
    systemd.user.services.super-productivity = {
      Unit = {
        Description = "Super Productivity";
        After = [ "graphical-session.target" ];
        PartOf = [ "graphical-session.target" ];
      };
      Service.ExecStart = lib.getExe pkgs.super-productivity;
      Install.WantedBy = [ "graphical-session.target" ];
    };
  };
}
