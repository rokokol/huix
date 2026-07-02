{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

{
  options.custom.printer.enable = lib.mkEnableOption "печать (CUPS + gutenprint)";

  config = lib.mkIf config.custom.printer.enable {
    programs.system-config-printer.enable = true;
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
      ];
    };

    users.users.${rokokolName} = {
      extraGroups = [
        "lp"
        "scanner"
      ];
    };
  };
}
