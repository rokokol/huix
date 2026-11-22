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

      environmentVariables = {
        # Jan sends Origin: null, and ollama's CORS rejects it
        OLLAMA_ORIGINS = "null*";
        # A quantized V cache needs flash attention, and q8_0 halves the cache at no measured quality cost
        OLLAMA_FLASH_ATTENTION = "1";
        OLLAMA_KV_CACHE_TYPE = "q8_0";
        # With little VRAM ollama picks a 4096-token window and silently cuts longer prompts
        OLLAMA_CONTEXT_LENGTH = "8192";
      };
    };

    environment.sessionVariables = {
      OLLAMA_PORT = port;
    };
  };
}
