{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

let
  port = 9443;
in
{
  options.custom.meshtastic.enable = lib.mkEnableOption "Meshtastic (демон + веб-интерфейс)";

  config = lib.mkIf config.custom.meshtastic.enable {
    services.meshtasticd = {
      enable = true;
      settings = {
        Webserver = {
          Port = port;
          RootPath = "${pkgs.meshtastic-web}";
        };
        General = {
          MaxNodes = 200;
          MaxMessageQueue = 100;
        };
      };
    };

    # Доступ к serial-устройствам (USB Meshtastic)
    users.users.${rokokolName}.extraGroups = [
      "dialout"
    ];

    environment.sessionVariables = {
      MESHTASTIC_PORT = port;
    };
  };
}
