{ config, lib, ... }:

# The manager itself lives in github:rokokol/hyprland-screen-shader. Enabling it brings
# the keys, the picker and its rofi modi along — huix only says when, and waybar/shader.nix
# adds the indicator
{
  config = lib.mkIf config.rokokol.hyprland.enable {
    programs.screen-shader.enable = true;
  };
}
