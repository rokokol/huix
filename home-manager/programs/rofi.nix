{
  config,
  lib,
  pkgs,
  huixDir,
  ...
}:

{
  options.rokokol.rofi.enable = lib.mkEnableOption "rofi with its themes and modes" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.rofi.enable {
    programs.rofi = {
      enable = true;
      package = pkgs.rofi;

      plugins = with pkgs; [
        rofi-calc
      ];

      settings = {
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

        display-open-with = "🎯";
        display-open-with-all = "📚";

        sorting-method = "fzf";
      };
    };

    # The theme and its light/dark switch come from rokokol/ddlc-rofi-theme, and its fonts
    # are this repository's own; only the message's face differs from its default
    # monospace. toggle-theme.sh calls ddlc-rofi-theme on SUPER+A
    # No config.rasi and no configPath override: rofi resolves a theme name in
    # ~/.config/rofi/themes by itself, which is where the module puts both variants
    ddlc.rofi = {
      enable = true;
      monoFont = "DepartureMono Nerd Font Mono 12";
    };

    home.packages = with pkgs; [
      rofimoji
      wl-clipboard
    ];

    # The menu of scripts/rofi-open-with.sh, as the handler of the files whose type no app claims
    xdg.desktopEntries.open-with = {
      name = "Open with";
      exec = "${huixDir}/scripts/rofi-open-with.sh open %F";
      icon = "document-open";
      noDisplay = true;
    };

    xdg.mimeApps = {
      enable = true;
      defaultApplications."application/octet-stream" = "open-with.desktop";
    };
  };
}
