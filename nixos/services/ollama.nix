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
    };
  };
}
