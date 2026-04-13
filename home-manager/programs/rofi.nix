{ pkgs, config, ... }:

let
  darkTheme = pkgs.writeText "rofi-doki-dark.rasi" ''
    * {
      background-color: transparent;
      text-color: #f9ebf4;
      margin: 0px;
      padding: 0px;
    }

    window {
      location: center;
      width: 700px;
      border: 2px;
      border-color: rgba(255, 146, 186, 0.52);
      border-radius: 24px;
      dynamic: true;
      padding: 18px;
      background-color: #17121d;
      background-image: url("${./assets/rofi-doki-bubbles-dark.svg}", both);
    }

    inputbar {
      background-color: rgba(32, 24, 41, 0.9);
      text-color: #fff6fb;
      border: 1px;
      border-color: rgba(255, 146, 186, 0.28);
      margin: 4px 4px 14px 4px;
      padding: 14px 16px;
      border-radius: 18px;
      children: [ prompt, entry ];
    }

    prompt {
      text-color: #ff84ae;
      margin: 0px 10px 0px 0px;
      font: "Doki 13";
    }

    entry {
      placeholder: "Just Monika... or an app";
      placeholder-color: #bfa9ba;
      text-color: #f9ebf4;
    }

    listview {
      background-color: rgba(23, 18, 29, 0.22);
      margin: 0px 4px 4px 4px;
      padding: 6px;
      border-radius: 20px;
      columns: 1;
      lines: 6;
      spacing: 8px;
      fixed-height: false;
    }

    element {
      orientation: horizontal;
      padding: 10px 14px;
      spacing: 12px;
      border-radius: 18px;
      border: 1px;
      border-color: #483352;
      background-color: rgba(35, 26, 43, 0.92);
    }

    element-icon {
      background-color: rgba(255, 132, 174, 0.12);
      padding: 8px;
      size: 40px;
      horizontal-align: 0.5;
      vertical-align: 0.5;
      border-radius: 12px;
    }

    element-text {
      horizontal-align: 0;
      vertical-align: 0.5;
      font: "DepartureMono Nerd Font Mono 12";
    }

    element selected {
      background-color: #ff84ae;
      border-color: #ff84ae;
      text-color: #17121d;
    }

    element selected element-icon {
      background-color: rgba(23, 18, 29, 0.15);
    }

    element alternate {
      background-color: rgba(41, 31, 49, 0.94);
    }

    message {
      margin: 8px 10px 0px 10px;
      padding: 10px 14px;
      background-color: rgba(255, 132, 174, 0.14);
      border: 1px;
      border-color: rgba(255, 241, 247, 0.18);
      border-radius: 16px;
    }

    textbox {
      text-color: #fff6fb;
      font: "DepartureMono Nerd Font Mono 12";
    }
  '';

  lightTheme = pkgs.writeText "rofi-doki-light.rasi" ''
    * {
      background-color: transparent;
      text-color: #574552;
      margin: 0px;
      padding: 0px;
    }

    window {
      location: center;
      width: 700px;
      border: 2px;
      border-color: rgba(245, 142, 182, 0.84);
      border-radius: 24px;
      dynamic: true;
      padding: 18px;
      background-color: #fff8fc;
      background-image: url("${./assets/rofi-doki-bubbles-light.svg}", both);
    }

    inputbar {
      background-color: rgba(255, 250, 253, 0.92);
      text-color: #f15b99;
      border: 1px;
      border-color: rgba(245, 142, 182, 0.38);
      margin: 4px 4px 14px 4px;
      padding: 14px 16px;
      border-radius: 18px;
    }

    prompt {
      text-color: #f15b99;
      margin: 0px 10px 0px 0px;
      font: "Doki 13";
    }

    entry {
      placeholder: "Okay, everyone!";
      placeholder-color: rgba(87, 69, 82, 0.54);
      text-color: #574552;
    }

    listview {
      background-color: rgba(255, 255, 255, 0.45);
      margin: 0px 4px 4px 4px;
      padding: 6px;
      border-radius: 20px;
      columns: 1;
      lines: 6;
      spacing: 8px;
      fixed-height: false;
    }

    element {
      orientation: horizontal;
      padding: 10px 14px;
      spacing: 12px;
      border-radius: 18px;
      border: 1px;
      border-color: rgba(248, 185, 209, 0.92);
      background-color: rgba(255, 255, 255, 0.88);
    }

    element-icon {
      background-color: rgba(255, 122, 162, 0.1);
      padding: 8px;
      size: 40px;
      horizontal-align: 0.5;
      vertical-align: 0.5;
      border-radius: 12px;
    }

    element-text {
      horizontal-align: 0;
      vertical-align: 0.5;
      font: "DepartureMono Nerd Font Mono 12";
    }

    element selected {
      background-color: #ff86af;
      border-color: #ff86af;
      text-color: #ffffff;
    }

    element selected element-icon {
      background-color: rgba(255, 255, 255, 0.18);
    }

    element alternate {
      background-color: rgba(255, 245, 249, 0.96);
    }

    message {
      margin: 8px 10px 0px 10px;
      padding: 10px 14px;
      background-color: rgba(255, 122, 162, 0.16);
      border: 1px;
      border-color: rgba(255, 255, 255, 0.72);
      border-radius: 16px;
    }

    textbox {
      text-color: #f15b99;
      font: "DepartureMono Nerd Font Mono 12";
    }
  '';

  rofiDoki = pkgs.writeShellScriptBin "rofi-doki" ''
    set -euo pipefail

    gtk_theme_key="/org/gnome/desktop/interface/gtk-theme"
    color_scheme_key="/org/gnome/desktop/interface/color-scheme"

    current_theme="$(${pkgs.dconf}/bin/dconf read "$gtk_theme_key" 2>/dev/null || true)"
    current_scheme="$(${pkgs.dconf}/bin/dconf read "$color_scheme_key" 2>/dev/null || true)"

    if [[ "''${current_theme,,}" == *"dark"* ]] || [[ "$current_scheme" == "'prefer-dark'" ]]; then
      theme_file="${darkTheme}"
    else
      theme_file="${lightTheme}"
    fi

    exec ${config.programs.rofi.finalPackage}/bin/rofi -theme "$theme_file" "$@"
  '';
in
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
  };

  home.packages = with pkgs; [
    rofimoji
    wl-clipboard
    rofiDoki
  ];
}
