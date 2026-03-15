{
  lib,
  pkgs,
  ...
}:

{
  options.services.ollama = {
  };

  config = {
    services.ollama = {
      enable = true;
      package = lib.mkDefault pkgs.ollama;
    };
  };
}
