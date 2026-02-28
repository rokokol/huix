{ pkgs, ... }:

{
  services.searx = {
    enable = true;
    package = pkgs.searxng;

    configureUwsgi = true;
    uwsgiConfig = {
      disable-logging = true;
      workers = 8;
      threads = 4;
      http = "127.0.0.1:9000";
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
        theme_args = {
          simple_style = "light";
        };
      };

      ui = {
        hotkeys = "vim";
      };

      engines = [
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
      };
    };
  };
}
