{
  lib,
  pkgs,
  ...
}:

let
  port = 11434;
in
{
  services.ollama = {
    enable = true;
    package = lib.mkDefault pkgs.stable.ollama;
    host = "127.0.0.1";
    port = port;

    environmentVariables.OLLAMA_ORIGINS = "null*"; # Jan sends Origin: null, ollama's CORS rejects it
  };

  environment.sessionVariables = {
    OLLAMA_PORT = port;
  };
}
