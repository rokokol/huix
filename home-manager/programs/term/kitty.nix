{ base16, lib, ... }:

let
  c = base16.dark;
  # The 16 ANSI slots as base16 fills them: eight hues, then brights that repeat all but 0, 7, 15
  ansi = [
    "base00"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base05"
    "base03"
    "base08"
    "base0B"
    "base0A"
    "base0D"
    "base0E"
    "base0C"
    "base07"
  ];
in
{
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
      wayland_titlebar_color = "system";

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

      background = c.base00;
      foreground = c.base05;
      cursor = c.base05;
      cursor_text_color = c.base00;
      selection_background = c.base02;
      selection_foreground = c.base00;
      url_color = c.base04;
    }
    // lib.listToAttrs (lib.imap0 (i: slot: lib.nameValuePair "color${toString i}" c.${slot}) ansi);
  };
}
