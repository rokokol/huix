{ config, lib, ... }:

# The manager itself lives in github:rokokol/hyprland-screen-shader. Enabling it brings
# the keys, the picker and its rofi modi along — huix only says when, and waybar/shader.nix
# adds the indicator
# The module emits its own restore call on the start and reload events (the shader slot
# is lost on every reload) — don't add that handler to hyprland.lua as well
{
  config = lib.mkIf config.rokokol.hyprland.enable {
    programs.screen-shader.enable = true;
  };
}
