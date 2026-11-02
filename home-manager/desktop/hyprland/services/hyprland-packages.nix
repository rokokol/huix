{
  config,
  lib,
  pkgs,
  ...
}:

{
  imports = [ ./hypridle.nix ];

  config = lib.mkIf config.rokokol.hyprland.enable {
    services.swayosd.enable = true;
    services.playerctld.enable = true;

    home.packages = with pkgs; [
      kitty
      awww
      dex
      hypridle
      hyprpolkitagent
      hyprpicker
      libnotify
      pavucontrol
      cliphist
      grim
      slurp
      satty
      jq
      curl
      imagemagick
      lm_sensors
      rofimoji
      swayosd
      wl-clipboard
      (tesseract5.override {
        enableLanguages = [
          "rus"
          "eng"
        ];
      })
    ];
  };
}
