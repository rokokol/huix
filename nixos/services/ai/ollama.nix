{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 11434;
in
{
  options.rokokol.ollama.enable = lib.mkEnableOption "the Ollama server" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.ollama.enable {
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
  };
}
