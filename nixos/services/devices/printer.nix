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

    # Bidirectional passes land out of step and smear text sideways, and escputil cannot realign the L120
    hardware.printers = {
      ensureDefaultPrinter = "EPSON-L120-Series";
      ensurePrinters = [
        {
          name = "EPSON-L120-Series";
          description = "EPSON L120 Series";
          deviceUri = "usb://EPSON/L120%20Series";
          model = "gutenprint.5.3://escp2-l120/expert";
          ppdOptions = {
            PageSize = "A4";
            StpPrintingDirection = "Unidirectional";
          };
        }
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
