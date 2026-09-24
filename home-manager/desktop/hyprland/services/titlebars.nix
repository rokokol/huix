{
  config,
  lib,
  pkgs,
  palette,
  ...
}:

# The bars are for a finger: off in the config, and tablet-mode.sh turns the enabled keyword
# on when the laptop is folded. Windows that draw their own close button get none
let
  cfg = config.rokokol.hyprland;
  inherit (palette) bare;
in
{
  options.rokokol.hyprland.titlebars = lib.mkEnableOption "titlebars with close and fullscreen buttons, shown in tablet mode (hyprbars, laptop only)";

  config = lib.mkIf (cfg.enable && cfg.titlebars) {
    wayland.windowManager.hyprland = {
      plugins = with pkgs.hyprlandPlugins; [ hyprbars ];

      settings.plugin.hyprbars = {
        enabled = false;
        bar_height = 22;
        bar_color = "rgba(${bare.jacket}ee)";
        "col.text" = "rgb(${bare.paper})";
        # A Nerd Font, because the buttons are its glyphs (the icon font is patched to follow
        # this option, see WORKAROUNDS.md)
        bar_text_font = "DepartureMono Nerd Font Mono";
        bar_text_size = 11;
        bar_buttons_alignment = "right";
        bar_part_of_window = true;
        bar_precedence_over_border = true;
        # The fullscreen button does what SUPER+F does
        "hyprbars-button" = [
          "rgb(${bare.bow}), 14, 󰖭, hyprctl dispatch killactive"
          "rgb(${bare.plum}), 14, 󰊓, hyprctl dispatch fullscreen 0"
        ];
      };

      # A window that draws its own close button, or that has no room for a bar
      extraConfig = ''
        windowrule {
            name = no-titlebar-own-buttons
            match:class = ^(com\.ayugram\.desktop|md\.obsidian\.Obsidian|superproductivity)$
            hyprbars:no_bar = true
        }

        windowrule {
            name = no-titlebar-pinned
            match:class = ^(desktop-pin.*|hyprland-run)$
            hyprbars:no_bar = true
        }
      '';
    };
  };
}
