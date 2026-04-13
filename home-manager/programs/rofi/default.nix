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

    font = "sans 13";

    extraConfig = {
      modi = "drun,calc";
      show-icons = false;

      display-drun = "Apps";
      display-calc = "Calc";
      display-top = "Top";
      display-mpd = "Music";
      display-power = "Power";

      display-emoji = "Emoji";
      display-math = "Math";
      display-chars = "Chars";
      display-clip = "Clipboard";
      display-kaomoji = "Kaomoji";
      display-dictionary = "Dictionary";
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
