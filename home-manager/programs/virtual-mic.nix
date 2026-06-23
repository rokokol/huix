{ pkgs, huixDir, ... }:

let
  virtual-mic = pkgs.writeShellApplication {
    name = "virtual-mic";
    runtimeInputs = with pkgs; [
      ffmpeg
      pulseaudio
      coreutils
    ];
    text = ''
      exec bash "${huixDir}/scripts/virtual-mic.sh" "$@"
    '';
  };
in
{
  home.packages = [ virtual-mic ];
}
