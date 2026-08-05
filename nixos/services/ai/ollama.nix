{
  lib,
  pkgs,
  ...
}:

{
  services.ollama = {
    enable = true;
    package = lib.mkDefault pkgs.stable.ollama;
    host = "127.0.0.1";
    port = 11434;
  };
}
