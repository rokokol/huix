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
      host = "0.0.0.0";
    };
  };

}
