{ pkgs, ... }:

{
  services.searx = {
    enable = true;
    package = pkgs.searxng;

    redisCreateLocally = true;

    uwsgiConfig = {
      disable-logging = true;
      workers = 1;
      threads = 4;
    };

    settings = {
      server = {
        port = 9000;
        bind_address = "127.0.0.1";
        secret_key = "9eb250a7fabc56fd385e058b2375ef4e42f42aa1cba587aa6a9821430fc59802";
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
          name = "openlibrary";
          disabled = false;
        }
        {
          name = "dictzone";
          disabled = true;
        }
        {
          name = "lingva";
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
          name = "karmasearch";
          disabled = true;
        }
        {
          name = "karmasearch videos";
          disabled = true;
        }
        {
          name = "startpage";
          disabled = true;
        }
        {
          name = "aol";
          disabled = true;
        }
        {
          name = "aol";
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
        {
          name = "openlibrary";
          disabled = false;
        }
        {
          name = "hoogle";
          disabled = true;
        }
        {
          name = "nixos wiki";
          disabled = false;
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
          name = "huggingface";
          disabled = false;
        }
      ];
    };
  };

  services.nginx = {
    enable = true;
    virtualHosts."localhost" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:9000";
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
}
