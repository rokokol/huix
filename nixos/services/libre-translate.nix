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

  systemd.services.libretranslate-warmup = {
    description = "Warm up LibreTranslate models in RAM";
    wantedBy = [ "multi-user.target" ];
    after = [ "libretranslate.service" ];
    requires = [ "libretranslate.service" ];

    serviceConfig = {
      Type = "oneshot";
      TimeoutSec = 120;
    };

    script = ''
      until ${pkgs.curl}/bin/curl -f -s "http://127.0.0.1:${toString port}/" > /dev/null; do
        sleep 2
      done

      echo "Starting EN -> RU warmup..."
      ${pkgs.curl}/bin/curl -f -X POST "http://127.0.0.1:${toString port}/translate" \
        -H "Content-Type: application/json" \
        -d '{"q": "warmup", "source": "en", "target": "ru"}'

      echo -e "\nStarting RU -> EN warmup..."
      ${pkgs.curl}/bin/curl -f -X POST "http://127.0.0.1:${toString port}/translate" \
        -H "Content-Type: application/json" \
        -d '{"q": "прогрев", "source": "ru", "target": "en"}'
    '';
  };

  environment.sessionVariables = {
    LIBRE_TRANSLATE_PORT = port;
  };
}
