{ pkgs, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;

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

      display-ru-en = "🇷🇺>🇺🇸";
      display-en-ru = "🇺🇸>🇷🇺";

      display-notifications = "💌";

      sorting-method = "fzf";
    };
  };

  # The theme and its light/dark switch live in rokokol/ddlc-rofi-theme; only the fonts
  # are ours, because it ships none. toggle-theme.sh calls ddlc-rofi-theme on SUPER+A
  ddlc.rofi = {
    enable = true;
    promptFont = "Doki 13";
    monoFont = "DepartureMono Nerd Font Mono 12";
    placeholder = "Okay, everyone!";
  };

  home.packages = with pkgs; [
    rofimoji
    wl-clipboard
  ];
}
