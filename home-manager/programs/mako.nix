{ ... }:
{
  services.mako = {
    enable = true;
    
    settings = {
      # Check man mako(5)
      anchor = "top-right";
      font = "Doki 12";
      padding = "15";
      
      border-radius = 8;
      border-size = 3;
      
      icons = 1;
      "max-icon-size" = 48;
      
      # --- Цветовая градация (DDLC Style) ---
      
      # [LOW] - Нежное, почти белое
      "urgency=low" = {
        "background-color" = "#fff0f5";
        "text-color" = "#884466";
        "border-color" = "#ffcceeff";
        "progress-color" = "over #ffb6c1";
        "default-timeout" = 4000;
      };

      # [NORMAL] - Классический розовый
      "urgency=normal" = {
        "background-color" = "#ffe6f2";
        "text-color" = "#5a2e45";
        "border-color" = "#ff69b4";
        "progress-color" = "over #ff1493";
        "default-timeout" = 8000;
      };

      # [CRITICAL] - Стиль Моники / Глитч
      "urgency=critical" = {
        "background-color" = "#ffb3d9";
        "text-color" = "#4a0028";
        "border-color" = "#ff0055";
        "progress-color" = "over #ff0000";
        "default-timeout" = 20000;
      };
    };
  };
}
