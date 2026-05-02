{
  config,
  pkgs,
  inputs,
  ...
}:

{
  programs.firefox = {
    enable = true;
    package = inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default;

    profiles.${config.home.username} = {
      isDefault = true;

      search = {
        default = "SearXNG";
        force = true; # Принудительно заменяет дефолтные поисковики
        engines = {
          "SearXNG" = {
            # Ссылаемся на твой Nginx proxy
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
        # Разрешаем автоматическую активацию расширений, загруженных через Mozilla Sync
        "extensions.autoDisableScopes" = 0;
      };
    };
  };
}
