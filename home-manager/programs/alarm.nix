{ pkgs, huixDir, ... }:

let
  # freedesktop sound theme ships a proper alarm clip; reference it directly.
  alarmSound = "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga";

  # Thin wrapper around scripts/alarm.sh: puts dependencies on PATH and passes
  # the sound path. The logic itself lives in the script
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
