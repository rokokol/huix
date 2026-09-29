{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

{
  options.rokokol.printer.enable = lib.mkEnableOption "printing (CUPS + gutenprint + Epson L120 driver)";

  config = lib.mkIf config.rokokol.printer.enable {
    programs.system-config-printer.enable = true;
    services.printing = {
      enable = true;
      drivers = with pkgs; [
        gutenprint
        epson_201310w
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
