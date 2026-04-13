{ pkgs, config, ... }:

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

      show-icons = true;
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

    theme =
      let
        inherit (config.lib.formats.rasi) mkLiteral;

        shell-bg = mkLiteral "#16111d";
        surface-bg = mkLiteral "#211829";
        surface-alt = mkLiteral "#2a1f35";
        outline-soft = mkLiteral "#433052";
        doki-pink = mkLiteral "#ff7aa2";
        doki-cream = mkLiteral "#fff3d8";
        text-main = mkLiteral "#f6e7ef";
        text-dim = mkLiteral "#bbaaba";
        text-selected = mkLiteral "#16111d";
      in
      {
        "*" = {
          background-color = mkLiteral "transparent";
          text-color = text-main;
          margin = mkLiteral "0px";
          padding = mkLiteral "0px";
        };

        "window" = {
          location = mkLiteral "center";
          width = mkLiteral "700px";
          border = mkLiteral "2px";
          border-color = mkLiteral "rgba(255, 122, 162, 0.55)";
          border-radius = mkLiteral "24px";
          dynamic = true;
          padding = mkLiteral "18px";
          background-color = shell-bg;
          background-image = mkLiteral ''url("${./assets/rofi-doki-bubbles.svg}", both)'';
        };

        "inputbar" = {
          background-color = mkLiteral "rgba(33, 24, 41, 0.88)";
          text-color = doki-cream;
          border = mkLiteral "1px";
          border-color = mkLiteral "rgba(255, 122, 162, 0.26)";
          margin = mkLiteral "4px 4px 14px 4px";
          padding = mkLiteral "14px 16px";
          border-radius = mkLiteral "18px";
          children = map mkLiteral [
            "prompt"
            "entry"
          ];
        };

        "prompt" = {
          text-color = doki-pink;
          margin = mkLiteral "0px 10px 0px 0px";
          font = "Doki 13";
        };

        "entry" = {
          placeholder = "Just Monika... or an app";
          placeholder-color = text-dim;
          text-color = text-main;
        };

        "listview" = {
          background-color = mkLiteral "rgba(22, 17, 29, 0.18)";
          margin = mkLiteral "0px 4px 4px 4px";
          padding = mkLiteral "6px";
          border-radius = mkLiteral "20px";
          columns = 1;
          lines = 6;
          spacing = mkLiteral "8px";
          fixed-height = false;
        };

        "element" = {
          orientation = mkLiteral "horizontal";
          padding = mkLiteral "10px 14px";
          spacing = mkLiteral "12px";
          border-radius = mkLiteral "18px";
          border = mkLiteral "1px";
          border-color = outline-soft;
          background-color = surface-bg;
        };

        "element-icon" = {
          background-color = mkLiteral "rgba(255, 122, 162, 0.1)";
          padding = mkLiteral "8px";
          size = mkLiteral "40px";
          horizontal-align = mkLiteral "0.5";
          vertical-align = mkLiteral "0.5";
          border-radius = mkLiteral "12px";
        };

        "element-text" = {
          horizontal-align = mkLiteral "0";
          vertical-align = mkLiteral "0.5";
          font = "DepartureMono Nerd Font Mono 12";
        };

        "element selected" = {
          background-color = doki-pink;
          border-color = doki-pink;
          text-color = text-selected;
        };

        "element selected element-icon" = {
          background-color = mkLiteral "rgba(22, 17, 29, 0.14)";
        };

        "element alternate" = {
          background-color = surface-alt;
        };

        "message" = {
          margin = mkLiteral "8px 10px 0px 10px";
          padding = mkLiteral "10px 14px";
          background-color = mkLiteral "rgba(255, 122, 162, 0.14)";
          border = mkLiteral "1px";
          border-color = mkLiteral "rgba(255, 243, 216, 0.16)";
          border-radius = mkLiteral "16px";
        };

        "textbox" = {
          text-color = doki-cream;
          font = "DepartureMono Nerd Font Mono 12";
        };
      };
  };

  home.packages = with pkgs; [
    rofimoji
    wl-clipboard
  ];
}
