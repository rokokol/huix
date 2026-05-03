{ ... }:

let
  nixSnowflakeIcon = "https://wiki.nixos.org/favicon.ico";
in
{
  programs.zen-browser = {
    enable = true;

    profiles.default = {
      isDefault = true;

      mods = [
        "03a8e7ef-cf00-4f41-bf24-a90deeafc9db" # colorful picker
        "a6335949-4465-4b71-926c-4a52d34bc9c0" # better search
        "906c6915-5677-48ff-9bfc-096a02a72379" # floating status bar
      ];

      search = {
        default = "SearXNG";
        force = true;
        engines = {
          "amazondotcom-us".metaData.hidden = true;
          "ebay-uk".metaData.hidden = true;
          "twitter".metaData.hidden = true;
          "ddg".metaData.hidden = true;
          "perplexity".metaData.hidden = true;
          "bing".metaData.hidden = true;

          "google" = {
            metaData.hidden = false;
            metaData.alias = "@g";
          };
          "wikipedia" = {
            metaData.hidden = false;
            metaData.alias = "@wiki";
          };

          "SearXNG" = {
            urls = [ { template = "http://localhost/search?q={searchTerms}"; } ];
            icon = "http://localhost/favicon.ico";
            definedAliases = [ "@s" ];
          };
          "NixOS Wiki" = {
            urls = [ { template = "https://wiki.nixos.org/w/index.php?search={searchTerms}"; } ];
            icon = nixSnowflakeIcon;
            definedAliases = [ "@nw" ];
          };
          "Wiby" = {
            urls = [ { template = "https://wiby.me/?q={searchTerms}"; } ];
            definedAliases = [ "@wb" ];
          };
          "GitHub" = {
            urls = [ { template = "https://github.com/search?q={searchTerms}"; } ];
            icon = "https://github.com/favicon.ico";
            definedAliases = [ "@gh" ];
          };
          "WolframAlpha" = {
            urls = [ { template = "https://www.wolframalpha.com/input/?i={searchTerms}"; } ];
            icon = "https://icons.duckduckgo.com/ip3/wolframalpha.com.ico";
            definedAliases = [ "@w" ];
          };

          "Nix Packages" = {
            urls = [
              {
                template = "https://search.nixos.org/packages";
                params = [
                  {
                    name = "type";
                    value = "packages";
                  }
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = nixSnowflakeIcon;
            definedAliases = [ "p" ];
          };

          "Nix Options" = {
            urls = [
              {
                template = "https://search.nixos.org/options";
                params = [
                  {
                    name = "channel";
                    value = "unstable";
                  }
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                ];
              }
            ];
            icon = nixSnowflakeIcon;
            definedAliases = [ "o" ];
          };

          "Home Manager Options" = {
            urls = [
              {
                template = "https://home-manager-options.extranix.com";
                params = [
                  {
                    name = "query";
                    value = "{searchTerms}";
                  }
                  {
                    name = "release";
                    value = "master";
                  }
                ];
              }
            ];
            icon = nixSnowflakeIcon;
            definedAliases = [ "hm" ];
          };
        };
      };
    };
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = builtins.listToAttrs (
      map
        (name: {
          inherit name;
          value = "zen-beta.desktop";
        })
        [
          "application/json"
          "application/x-extension-htm"
          "application/x-extension-html"
          "application/x-extension-shtml"
          "application/x-extension-xht"
          "application/x-extension-xhtml"
          "application/xhtml+xml"
          "text/html"
          "text/plain"
          "x-scheme-handler/about"
          "x-scheme-handler/chrome"
          "x-scheme-handler/http"
          "x-scheme-handler/https"
          "x-scheme-handler/mailto"
          "x-scheme-handler/unknown"
        ]
    );
  };
}
