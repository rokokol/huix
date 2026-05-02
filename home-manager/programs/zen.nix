{
  config,
  pkgs,
  ...
}:

{
  # Принудительно направляем Zen в папку, которую использует Home Manager
  home.file.".zen".source = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/zen";

  programs.zen-browser = {
    enable = true;

    profiles.default = {
      isDefault = true;
      path = "default";

      pins = {
        "YouTube" = {
          id = "youtube-essential";
          url = "https://www.youtube.com";
          isEssential = true;
        };
        "GitHub" = {
          id = "github-essential";
          url = "https://github.com";
          isEssential = true;
        };
      };

      search = {
        default = "SearXNG";
        force = true;
        engines = {
          "bing".metaData.hidden = true;
          "google" = {
            metaData.hidden = true;
            metaData.alias = "@g";
          };
          "amazondotcom-us".metaData.hidden = true;
          "ebay".metaData.hidden = true;
          "twitter".metaData.hidden = true;
          "wikipedia" = {
            metaData.hidden = false;
            metaData.alias = "@wiki";
          };
          "ddg".metaData.hidden = true;
          "perplexity".metaData.hidden = true;

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
            definedAliases = [ "@w" ];
          };
          "GitHub" = {
            urls = [ { template = "https://github.com/search?q={searchTerms}"; } ];
            icon = "https://github.com/favicon.ico";
            definedAliases = [ "@gh" ];
          };
        };
      };

      settings = {
        "zen.window-sync.enabled" = true;
        "zen.window-sync.sync-only-pinned-tabs" = true;
        "extensions.autoDisableScopes" = 0;
        "browser.shell.checkDefaultBrowser" = false;
        "browser.sessionstore.resume_from_crash" = true;
        "privacy.sanitize.sanitizeOnShutdown" = false;
        "network.cookie.cookieBehavior" = 0;

        # Принудительное обновление закрепов при каждом запуске
        "zen.sync.essential-pins" = true;
        "browser.tabs.warnOnClose" = false;
      };
    };
  };
}
