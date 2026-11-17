{
  config,
  lib,
  pkgs,
  ...
}:

{
  options.rokokol.sound.enable = lib.mkEnableOption "PipeWire sound" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.sound.enable {
    services.pulseaudio.enable = false;
    security.rtkit.enable = true;
    environment.systemPackages = with pkgs; [ pipewire.jack ];

    services.pipewire = {
      enable = true;
      alsa.enable = true;
      alsa.support32Bit = true;
      pulse.enable = true;
    };
  };
}
