{ pkgs, huixDir, ... }:

let
  # Тонкая обёртка над scripts/virtual-mic.sh: кладёт зависимости в PATH.
  # Сама логика (создание источника, ffmpeg) живёт в скрипте.
  virtual-mic = pkgs.writeShellApplication {
    name = "virtual-mic";
    runtimeInputs = with pkgs; [
      ffmpeg
      pulseaudio # pactl — создание виртуального источника в PipeWire
      coreutils # mktemp/mkfifo/rm для FIFO
    ];
    text = ''
      exec bash "${huixDir}/scripts/virtual-mic.sh" "$@"
    '';
  };
in
{
  home.packages = [ virtual-mic ];
}
