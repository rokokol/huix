{
  config,
  lib,
  huixDir,
  ...
}:

let
  cfg = config.custom.hyprland;
in
{
  options.custom.hyprland.lidNoSleep =
    lib.mkEnableOption "тумблер \"крышка гасит экран, а не усыпляет\" (только ноутбук)";

  config = lib.mkIf (cfg.enable && cfg.lidNoSleep) {
    # hyprland.conf общий для обоих хостов, поэтому ноутбучные бинды живут здесь.
    # Настройки из settings идут ДО source общего конфига, значит $mainMod ещё
    # не определён — модификатор пишем буквально.
    wayland.windowManager.hyprland.settings = {
      bind = [ "SUPER SHIFT, A, exec, ${huixDir}/scripts/lid-mode.sh toggle" ];

      # bindl — срабатывает и при заблокированном экране. Имя устройства берётся
      # из hyprctl devices; сам гасящий/будящий dpms делает скрипт, причём close
      # молчит, когда режим выключен (тогда крышку обрабатывает logind).
      bindl = [
        ", switch:on:Lid Switch, exec, ${huixDir}/scripts/lid-mode.sh close"
        ", switch:off:Lid Switch, exec, ${huixDir}/scripts/lid-mode.sh open"
      ];
    };
  };
}
