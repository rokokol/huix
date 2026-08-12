{ ... }:

# The camera half is a system concern (kernel module) and lives in configuration-pc.nix
{
  programs.virtual-media-devices.microphone.enable = true;
}
