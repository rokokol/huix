{
  config,
  lib,
  pkgs,
  ...
}:

let
  port = 9000;
in
{
  options.custom.searxng.enable = lib.mkEnableOption "SearxNG behind nginx";

  config = lib.mkIf config.custom.searxng.enable {
    sops.secrets."searxng-secret-key" = { };

    # The searx module runs settings.yml through envsubst, so the key arrives as $VAR at
    # startup instead of being baked into the store
    sops.templates."searxng.env".content = ''
      SEARXNG_SECRET_KEY=${config.sops.placeholder."searxng-secret-key"}
    '';

    services.searx = {
      environmentFile = config.sops.templates."searxng.env".path;
      enable = true;
      package = pkgs.searxng;

      redisCreateLocally = true;

      uwsgiConfig = {
        disable-logging = true;
        workers = 2;
        threads = 4;
        offload-threads = 4;
      };

      settings = {
        server = {
          inherit port;
          bind_address = "127.0.0.1";
          secret_key = "$SEARXNG_SECRET_KEY";
          base_url = "http://localhost/";
          method = "POST";
        };

        search = {
          autocomplete = "duckduckgo";
          formats = [
            "html"
            "json"
          ];
        };

        ui = {
          theme_args.simple_style = "light";
          hotkeys = "vim";
        };

        engines = [
          {
            name = "aol";
            disabled = true;
          }
          {
            name = "bing";
            disabled = false;
          }
          {
            name = "brave";
            disabled = true;
          }
          {
            name = "dictzone";
            disabled = true;
          }
          {
            name = "gitlab";
            disabled = false;
          }
          {
            name = "habrahabr";
            disabled = false;
          }
          {
            name = "hoogle";
            disabled = true;
          }
          {
            name = "huggingface";
            disabled = false;
          }
          {
            name = "karmasearch videos";
            disabled = true;
          }
          {
            name = "karmasearch";
            disabled = true;
          }
          {
            name = "lingva";
            disabled = true;
          }
          {
            name = "nixos wiki";
            disabled = false;
          }
          {
            name = "openlibrary";
            disabled = false;
          }
          {
            name = "startpage";
            disabled = true;
          }
          {
            name = "wolframalpha";
            disabled = false;
          }
          {
            name = "yandex";
            disabled = false;
          }
        ];
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."localhost" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString port}";
          proxyWebsockets = true;

          extraConfig = ''
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
          '';
        };
      };
    };
  };
}
