{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

{
  options.rokokol.printer.enable = lib.mkEnableOption "printing (CUPS + gutenprint)";

  config = lib.mkIf config.rokokol.printer.enable {
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
