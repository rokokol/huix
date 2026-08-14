{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 8088;
in
{
  options.rokokol.openwebui.enable = lib.mkEnableOption "Open WebUI";

  config = lib.mkIf config.rokokol.openwebui.enable {
    services.open-webui = {
      enable = true;
      host = "127.0.0.1";
      inherit port;

      package = pkgs.open-webui;

      environment = {
        OLLAMA_API_BASE_URL = "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
      };
    };

    environment.sessionVariables = {
      OPEN_WEBUI_PORT = port;
    };
  };
}
