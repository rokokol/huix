{ ... }:

{
  programs.zen-browser = {
    enable = true;

    profiles.default = {
      isDefault = true;

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
            icon = "https://wiki.nixos.org/favicon.ico";
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
            icon = "https://www.wolframalpha.com/favicon.ico";
            definedAliases = [ "@w" ];
          };
        };
      };
    };
  };
}
