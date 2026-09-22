{ lib, pkgs, ... }:

let
  port = 11434;
in
{
  services.ollama = {
    enable = true;
    package = lib.mkDefault pkgs.stable.ollama;
    host = "127.0.0.1";
    inherit port;

    # Jan sends Origin: null, and ollama's CORS rejects it
    environmentVariables.OLLAMA_ORIGINS = "null*";
  };

  environment.sessionVariables = {
    OLLAMA_PORT = port;
  };
}
