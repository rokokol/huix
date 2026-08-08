{
  pkgs,
  config,
  lib,
  palette,
  ...
}:

let
  rofiConfigDir = "${config.xdg.configHome}/rofi";
  rofiThemesDir = "${rofiConfigDir}/themes";
  themes = import ./theme.nix { inherit palette; };
in
{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;
    configPath = "${rofiConfigDir}/base.rasi";

    plugins = with pkgs; [
      rofi-calc
    ];

    font = "Doki 12";

    extraConfig = {
      modi = "drun,calc";
      show-icons = false;

      display-drun = "👀";
      display-calc = "🧮";
      display-top = "📊";
      display-mpd = "🎼";
      display-power = "⚡";

      display-emoji = "💀";
      display-math = "∰";
      display-chars = "¥";
      display-clip = "📋";
      display-kaomoji = "(,,#ﾟДﾟ)";
      display-dictionary = "🤓";
      sorting-method = "fzf";

      display-ru-en = "🇷🇺>🇺🇸";
      display-en-ru = "🇺🇸>🇷🇺";

      display-shader = "📺";
      display-notifications = "💌";
    };
  };

  xdg.configFile."rofi/config.rasi".text = ''
    @import "${config.programs.rofi.configPath}"
    @theme "${rofiThemesDir}/active.rasi"
  '';

  xdg.configFile."rofi/assets/polka-light.svg".text = themes.polkaLight;
  xdg.configFile."rofi/assets/polka-dark.svg".text = themes.polkaDark;

  xdg.configFile."rofi/themes/light.rasi".text = themes.light;
  xdg.configFile."rofi/themes/dark.rasi".text = themes.dark;

  home.sessionVariables = {
    ROFI_THEMES_DIR = rofiThemesDir;
    ROFI_LIGHT_THEME = "${rofiThemesDir}/light.rasi";
    ROFI_DARK_THEME = "${rofiThemesDir}/dark.rasi";
    ROFI_ACTIVE_THEME = "${rofiThemesDir}/active.rasi";
  };

  home.activation.rofiInitActiveTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ ! -e "${rofiThemesDir}/active.rasi" ]; then
      ln -sfn "${rofiThemesDir}/light.rasi" "${rofiThemesDir}/active.rasi"
    fi
  '';

  home.packages = with pkgs; [
    rofimoji
    wl-clipboard
  ];
}
