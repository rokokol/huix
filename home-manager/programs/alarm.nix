{ pkgs, huixDir, ... }:

let
  # freedesktop sound theme ships a proper alarm clip; reference it directly.
  alarmSound = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";

  # Тонкая обёртка над scripts/alarm.sh: кладёт зависимости в PATH и передаёт
  # путь к звуку. Сама логика живёт в скрипте.
  alarm = pkgs.writeShellApplication {
    name = "alarm";
    runtimeInputs = with pkgs; [
      coreutils
      gawk
      libnotify
      procps
      wireplumber
      pipewire
    ];
    text = ''
      export ALARM_SOUND="${alarmSound}"
      exec bash "${huixDir}/scripts/alarm.sh" "$@"
    '';
  };
in
{
  home.packages = [ alarm ];
}
