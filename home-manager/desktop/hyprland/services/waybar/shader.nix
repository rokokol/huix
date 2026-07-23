{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.custom.waybar;
  # SIGRTMIN+N для обновления индикатора; не пересекаться с notifications.nix (9)
  shaderSignal = 8;
in
{
  options.custom.waybar.shader = lib.mkEnableOption "индикатор полноэкранных шейдеров и софт-яркости";

  config = lib.mkIf (cfg.enable && cfg.shader) {
    home.sessionVariables.WAYBAR_SHADER_SIGNAL = toString shaderSignal;

    programs.waybar.settings.mainBar."custom/shader" = {
      exec = "${huixDir}/scripts/screen-shader.sh status";
      return-type = "json";
      format = "{}";
      signal = shaderSignal;
      on-click = "${huixDir}/scripts/rofi-shader.sh";
      on-click-right = "${huixDir}/scripts/screen-shader.sh effect clear";
      on-click-middle = "${huixDir}/scripts/screen-shader.sh bright toggle";
      on-scroll-up = "${huixDir}/scripts/screen-shader.sh bright up";
      on-scroll-down = "${huixDir}/scripts/screen-shader.sh bright down";
    };
  };
}
