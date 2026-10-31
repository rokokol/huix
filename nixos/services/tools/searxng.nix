{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.rokokol.searxng;
in
{
  options.rokokol.searxng = {
    enable = lib.mkEnableOption "SearxNG behind nginx";
    port = lib.mkOption {
      type = lib.types.port;
      default = 9000;
      description = "Loopback port of the SearXNG instance behind nginx";
    };
    publicPort = lib.mkOption {
      type = lib.types.port;
      default = 9001;
      description = "Tailnet port publishing SearXNG";
    };
  };

  config = lib.mkIf config.rokokol.searxng.enable {
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
        workers = 4;
        threads = 8;
        offload-threads = 4;
      };

      settings = {
        server = {
          inherit (cfg) port;
          bind_address = "127.0.0.1";
          secret_key = "$SEARXNG_SECRET_KEY";
          base_url = "http://localhost/";
          method = "POST";
          limiter = false;
          public_instance = false;
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
            name = "brave";
            disabled = false;
          }
          {
            name = "duckduckgo";
            disabled = false;
          }
          {
            name = "github";
            disabled = false;
          }
          {
            name = "huggingface";
            disabled = false;
          }
          {
            name = "mojeek";
            disabled = false;
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
            name = "stackoverflow";
            disabled = false;
          }
          {
            name = "wikipedia";
            disabled = false;
          }
          {
            name = "wolframalpha";
            disabled = false;
          }
          {
            name = "aol";
            disabled = true;
          }
          {
            name = "bing";
            disabled = true;
          }
          {
            name = "dictzone";
            disabled = true;
          }
          {
            name = "gitlab";
            disabled = true;
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
            name = "qwant";
            disabled = true;
          }
          {
            name = "startpage";
            disabled = true;
          }
          {
            name = "yandex";
            disabled = true;
          }
        ];
      };
    };

    services.nginx = {
      enable = true;
      virtualHosts."localhost" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${toString cfg.port}";
          proxyWebsockets = true;
          recommendedProxySettings = true;
        };
      };
    };

    rokokol.tailnet-web.sites.searxng = {
      port = cfg.publicPort;
      backend = "http://127.0.0.1:${toString cfg.port}";
    };
  };
}
