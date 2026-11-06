{
  config,
  lib,
  inputs,
  ...
}:

let
  inherit (inputs.ddlc-themes.lib) kitty;
in
{
  imports = [ inputs.ddlc-themes.homeModules.default ];

  options.rokokol.kitty = {
    enable = lib.mkEnableOption "the kitty terminal" // {
      default = config.rokokol.workstation.enable;
    };
    snow.enable = lib.mkEnableOption "snow in the kitty terminal" // {
      default = true;
    };
  };

  config = lib.mkIf config.rokokol.kitty.enable {
    # The colours land after everything below, and kitty takes the last word for a key
    ddlc.kitty.enable = true;

    # kitty swaps to these as the desktop colour scheme flips, which toggle-theme.sh does; the
    # colours above stay the answer when the desktop states no preference
    xdg.configFile = {
      "kitty/dark-theme.auto.conf".source = kitty.dark;
      "kitty/light-theme.auto.conf".source = kitty.light;
    }
    // lib.optionalAttrs config.rokokol.kitty.snow.enable {
      "kitty/shaders/edge-snow.pipeline".text = ''
        startgroup
            animation_start os-window-focus-in
            animation_stop never
            animation_step 50
            shaders edge-snow
        endgroup
      '';
      "kitty/shaders/edge-snow.slang".text = ''
        #language slang 2026
        import kitty_custom_shader_types;
        #define vec2 float2
        #define fract frac
        ${builtins.readFile ../../../assets/snow-core.glsl}

        public float4 fragment_main(float4 color, KittyTextures t, KittyCustomShaderData d) {
            float2 uv = t.pos - d.central_area.xy;
            if (any(uv < 0.0) || any(uv > d.central_area.zw)) return color;
            float2 size = d.central_area.zw * float2(d.viewport_size_pixels);
            float2 p = uv * float2(d.viewport_size_pixels);
            float edge = 1.0 - smoothstep(24.0, 80.0, size.y - p.y);
            if (edge <= 0.0 && p.y > 10.0) return color;
            float background = 1.0 - smoothstep(0.01, 0.04, length(color.rgb - d.active_window_background.rgb));
            float flakes = snow_flakes(p, d.timestamp) * edge * 0.4;
            float settled = snow_bank(p) * 0.35;
            return float4(lerp(color.rgb, d.foreground.rgb, max(flakes, settled) * background), color.a);
        }
      '';
    };

    programs.kitty = {
      enable = true;

      font = {
        name = "DepartureMono Nerd Font Mono";
        size = 12;
      };

      keybindings = {
        "ctrl+shift+c" = "copy_to_clipboard";
        "ctrl+shift+v" = "paste_from_clipboard";
        # Russian layout support
        "ctrl+shift+с" = "copy_to_clipboard";
        "ctrl+shift+м" = "paste_from_clipboard";
      };

      settings = {
        # Kitty's own shortcuts move off ctrl+shift, which the applications in it need:
        # `ctrl+shift+b` was `move_window_backward` and never reached pi, and `ctrl+shift+t`
        # opened a tab instead of reaching whatever wanted the key. The copy and paste
        # bindings above are explicit, so they stay where they are
        kitty_mod = "ctrl+alt";

        notify_on_cmd_finish = "unfocused 1.0";

        linux_display_server = "wayland";
        custom_shaders = lib.mkIf config.rokokol.kitty.snow.enable "edge-snow";

        window_padding_width = 12;
        hide_window_decorations = "yes";
        shell = "zsh";
        enable_audio_bell = true;

        cursor_trail = 50;
        cursor_trail_decay = "0.1 0.35";
        cursor_trail_start_threshold = 1;

        cursor_blink_interval = "0.5";
        cursor_stop_blinking_after = "15.0";
      };
    };
  };
}
