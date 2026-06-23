{ huixDir, ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;
    configType = "hyprlang";

    settings = {
      monitor = [
        ",preferred,auto,1"
      ];

      input = {
        kb_layout = "us,ru";
        kb_variant = "";
        kb_options = "grp:win_space_toggle";

        follow_mouse = 1;

        sensitivity = 0;
      };

      # Софт-яркость через шейдер: у десктоп-монитора нет аппаратной подсветки,
      # поэтому затемняем картинку шейдером Hyprland.
      # Модификаторы пишем литералом (SUPER ALT), т.к. эти настройки
      # рендерятся ДО source = hyprland.conf, где определён $mainScreenMod.
      bindel = [
        "SUPER CTRL, bracketright, exec, ${huixDir}/scripts/screen-shader.sh bright up"
        "SUPER CTRL, bracketleft,  exec, ${huixDir}/scripts/screen-shader.sh bright down"
      ];
      bind = [
        "SUPER ALT, backslash, exec, ${huixDir}/scripts/screen-shader.sh bright reset"
      ];
    };
  };

  imports = [
    ./services/wallpaper_collager.nix
    ./services/hyprland-packages.nix
    ./services/waybar-pc.nix
  ];
}
