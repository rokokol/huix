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
      until ${pkgs.curl}/bin/curl -s "http://127.0.0.1:$port" > /dev/null; do
        sleep 2
      done

      ${pkgs.curl}/bin/curl -s -X POST "http://127.0.0.1:$port/translate" \
        -H "Content-Type: application/json" \
        -d '{"q": "warmup", "source": "en", "target": "ru"}' > /dev/null

      ${pkgs.curl}/bin/curl -s -X POST "http://127.0.0.1:$port/translate" \
        -H "Content-Type: application/json" \
        -d '{"q": "прогрев", "source": "ru", "target": "en"}' > /dev/null
    '';
  };
}
