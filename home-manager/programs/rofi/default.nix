{ pkgs, config, ... }:

let
  rofiConfigDir = "${config.xdg.configHome}/rofi";
  rofiThemesDir = "${rofiConfigDir}/themes";
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
    };
  };

  xdg.configFile."rofi/config.rasi".text = ''
    @import "${config.programs.rofi.configPath}"
    @theme "${rofiThemesDir}/active.rasi"
  '';

  xdg.configFile."rofi/themes/light.rasi".source = ./theme-light.rasi;
  xdg.configFile."rofi/themes/dark.rasi".source = ./theme-dark.rasi;
  xdg.configFile."rofi/themes/active.rasi".source = ./theme-light.rasi;
  xdg.configFile."rofi/assets/polka-light.svg".source = ./assets/polka-light.svg;
  xdg.configFile."rofi/assets/polka-dark.svg".source = ./assets/polka-dark.svg;

  home.packages = with pkgs; [
    rofimoji
    wl-clipboard
  ];
}
