{ pkgs, config, ... }:

{
  programs.rofi = {
    enable = true;
    package = pkgs.rofi;

    plugins = with pkgs; [
        rofi-calc
        rofi-emoji
      ];
    
    font = "Doki 12";

    extraConfig = {
      modi = "drun,emoji,calc";
      show-icons = true;
      display-drun = "👀";
      display-emoji = "💀";
      display-calc = "🧮";
      sorting-method = "fzf";
    };

    theme = let 
      inherit (config.lib.formats.rasi) mkLiteral;
      
      # --- Палитра DDLC ---
      paper-bg = mkLiteral "#fffbf0";     
      notebook-line = mkLiteral "#bad0ef";
      doki-pink = mkLiteral "#ff7aa2";    
      text-main = mkLiteral "#594a4e";    
      text-selected = mkLiteral "#ffffff";
    in {
      "*" = {
        background-color = mkLiteral "transparent";
        text-color = text-main;
        margin = mkLiteral "0px";
        padding = mkLiteral "0px";
      };

      "window" = {
        location = mkLiteral "center";
        width = mkLiteral "700px";
        # height = mkLiteral "500px"; # To make the window dynamic
        
        border = mkLiteral "4px";
        border-color = doki-pink;
        border-radius = mkLiteral "15px";
        dynamic = true;
        
        background-color = paper-bg;
      };

      "inputbar" = {
        background-color = mkLiteral "rgba(255, 122, 162, 0.2)"; # Полупрозрачный розовый
        text-color = doki-pink;
        border = mkLiteral "0px 0px 2px 0px"; # Линия снизу
        border-color = doki-pink;
        
        margin = mkLiteral "20px 20px 10px 20px";
        padding = mkLiteral "10px";
        border-radius = mkLiteral "10px";
        children = map mkLiteral [ "prompt" "entry" ];
      };

      "prompt" = {
        text-color = doki-pink;
        margin = mkLiteral "0px 10px 0px 0px";
      };

      "entry" = {
        placeholder = "Okay, everyone!"; 
        placeholder-color = mkLiteral "rgba(89, 74, 78, 0.5)";
        text-color = text-main;
      };

      "listview" = {
        margin = mkLiteral "10px 20px 20px 20px";
        columns = 1;    
        lines = 5;      
        spacing = mkLiteral "5px"; 
	fixed-height = false;
      };

      "element" = {
        orientation = mkLiteral "horizontal"; 
        padding = mkLiteral "5px 10px";       
        spacing = mkLiteral "10px";           
        border-radius = mkLiteral "8px";
        border = mkLiteral "2px";             
        border-color = notebook-line;
        background-color = mkLiteral "#ffffff";
      };

      "element-icon" = {
        size = mkLiteral "48px";
        horizontal-align = mkLiteral "0.5"; 
        margin = mkLiteral "0px 0px 10px 0px";
      };

      "element-text" = {
        horizontal-align = mkLiteral "0.5"; 
        vertical-align = mkLiteral "0.5";
        font = "DepartureMono Nerd Font Mono 12"; 
      };

      "element selected" = {
        background-color = doki-pink;       
        border-color = doki-pink;
        text-color = text-selected;
      };

      "message" = {
        margin = mkLiteral "0px 40px 5px 40px";
        padding = mkLiteral "5px";
        background-color = mkLiteral "rgba(255, 122, 162, 0.3)"; 
        border-radius = mkLiteral "8px";
      };

      "textbox" = {
        text-color = doki-pink;
        font = "DepartureMono Nerd Font Mono 12"; 
      };
    };
  };
}
