{ config, lib, ... }:

# The camera half is a system concern (kernel module) and lives in configuration-pc.nix
{
  options.rokokol.virtual-mic.enable = lib.mkEnableOption "the virtual microphone" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.virtual-mic.enable {
    programs.virtual-media-devices.microphone.enable = true;
  };
}
