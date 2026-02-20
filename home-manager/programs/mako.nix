{ ... }:

{
  services.mako = {
    enable = true;

    settings = {
      anchor = "top-right";
      font = "Doki 12";
      padding = "15";

      border-radius = 8;
      border-size = 3;

      icons = 1;
      max-icon-size = 48;

      "urgency=low" = {
        background-color = "#e8f5e9";
        text-color = "#1b5e20";
        border-color = "#4caf50";
        default-timeout = 4000;
      };

      "urgency=normal" = {
        background-color = "#fff8e1";
        text-color = "#825e00";
        border-color = "#ffb300";
        default-timeout = 8000;
      };

      "urgency=critical" = {
        background-color = "#ffebee";
        text-color = "#b71c1c";
        border-color = "#e53935";
        default-timeout = 20000;
      };
    };
  };
}
