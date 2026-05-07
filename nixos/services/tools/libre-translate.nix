{ pkgs, ... }:

let
  port = 5000;
in
{
  services.libretranslate = {
    enable = true;
    port = port;
    updateModels = true;

    extraArgs = {
      "load-only" = "ru,en";
    };
  };

  environment.systemPackages = [ pkgs.libretranslate ];

  environment.sessionVariables = {
    LIBRE_TRANSLATE_PORT = port;
  };
}
