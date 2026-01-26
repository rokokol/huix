{ pkgs, ... }:

{
  programs.kitty = {
    enable = true;

    font = {
      name = "DepartureMono Nerd Font Mono";
      size = 12;
    };

    themeFile = "GruvboxMaterialDarkHard";

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
      hide_window_decorations = "no";
      shell = "zsh";
      enable_audio_bell = true;
    };
  };
}

