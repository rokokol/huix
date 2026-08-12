{ config, lib, ... }:

# The manager itself lives in github:rokokol/hyprland-screen-shader. Enabling it brings
# the keys, the picker and its rofi modi along — huix only says when, and waybar/shader.nix
# adds the indicator
# The module emits its own "exec = screen-shader restore" (the shader slot is lost on every
# reload) — don't add that line to hyprland.conf as well
{
  config = lib.mkIf config.rokokol.hyprland.enable {
    programs.screen-shader.enable = true;
  };
}
