{
  ...
}:

{
  programs.zen-browser = {
    enable = true;

    profiles.default = {
      isDefault = true;

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

          "google".metaData.alias = "@g";
          "wikipedia".metaData.alias = "@wiki";
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
      };
    };
  };
}
