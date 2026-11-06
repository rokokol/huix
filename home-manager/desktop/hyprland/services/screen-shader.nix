{ config, lib, ... }:

# The manager itself lives in github:rokokol/hyprland-screen-shader. Enabling it brings
# the keys, the picker and its rofi modi along — huix only says when, and waybar/shader.nix
# adds the indicator
# The module emits its own restore call on the start and reload events (the shader slot
# is lost on every reload) — don't add that handler to hyprland.lua as well
{
  config = lib.mkIf config.rokokol.hyprland.enable {
    programs.screen-shader = {
      enable = true;
      extraShaders.snow = ''
        // label: Snow
        // emoji: ❄️
        // order: 95
        // animated: yes
        // samples: no
        ${builtins.readFile ../../../../assets/snow-core.glsl}

        vec3 effect(vec3 c, vec2 uv) {
            vec2 size = vec2(textureSize(tex, 0));
            vec2 p = vec2(uv.x, 1.0 - uv.y) * size;
            float edge = 1.0 - smoothstep(32.0, 120.0, size.y - p.y);
            float flakes = snow_flakes(p, time) * edge * 0.45;
            float settled = snow_bank(p) * 0.50;
            return mix(c, vec3(1.0), max(flakes, settled));
        }
      '';
    };
  };
}
