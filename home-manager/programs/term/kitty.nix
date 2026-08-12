{ inputs, ... }:

{
  imports = [ inputs.ddlc-terminal-themes.homeManagerModules.default ];

  # The colours land after everything below, and kitty takes the last word for a key
  ddlc.kitty.enable = true;

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
      notify_on_cmd_finish = "unfocused 1.0";

      linux_display_server = "wayland";

      background_opacity = "0.9";
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
}
