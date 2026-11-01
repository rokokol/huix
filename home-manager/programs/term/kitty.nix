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

  options.rokokol.kitty.enable = lib.mkEnableOption "the kitty terminal" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.kitty.enable {
    # The colours land after everything below, and kitty takes the last word for a key
    ddlc.kitty.enable = true;

    # kitty swaps to these as the desktop colour scheme flips, which toggle-theme.sh does; the
    # colours above stay the answer when the desktop states no preference
    xdg.configFile = {
      "kitty/dark-theme.auto.conf".source = kitty.dark;
      "kitty/light-theme.auto.conf".source = kitty.light;
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
