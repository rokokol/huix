{
  lib,
  pkgs,
  ...
}:

{
  config = {
    services.ollama = {
      enable = true;
      package = lib.mkDefault pkgs.ollama;
      host = "127.0.0.1";
      port = 11434;
    };
  };
}
