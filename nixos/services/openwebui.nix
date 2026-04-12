{ pkgs, config, ... }:

{
  services.open-webui = {
    enable = true;
    host = "127.0.0.1";
    port = 8088;

    package = pkgs.open-webui;

    environment = {
      OLLAMA_API_BASE_URL =
        "http://${config.services.ollama.host}:${toString config.services.ollama.port}";
    };
  };
}
