{ ... }:

{
  services.libretranslate = {
    enable = true;
    port = 5000;
    updateModels = true;

    extraArgs = {
      "load-only" = "ru,en";
    };
  };
}
