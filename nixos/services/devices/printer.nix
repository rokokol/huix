{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

let
  # the filter prefixes its own resource directory to this name, see WORKAROUNDS.md
  epson-l120 = pkgs.epson_201310w.overrideAttrs (old: {
    postFixup = old.postFixup + ''
      substituteInPlace $out/share/cups/model/EPSON_L120.ppd \
        --replace-fail "$out/resource/Epson_201310w.1.data" "Epson_201310w.1.data"
    '';
  });
in
{
  options.rokokol.printer.enable = lib.mkEnableOption "printing (CUPS + gutenprint + Epson L120 driver)";

  config = lib.mkIf config.rokokol.printer.enable {
    programs.system-config-printer.enable = true;
    services.printing = {
      enable = true;
      drivers = [
        pkgs.gutenprint
        epson-l120
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
