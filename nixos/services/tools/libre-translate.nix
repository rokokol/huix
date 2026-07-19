{ pkgs, ... }:

let
  port = 5000;
  langs = "ru,en";
in
{
  services.libretranslate = {
    enable = true;
    port = port;
    updateModels = false;

    extraArgs = {
      "load-only" = langs;
    };
  };
}
