{ ... }:

{
  programs.nixvim.plugins.image = {
    enable = true;
    settings = {
      backend = "kitty";
      processor = "magick_cli";
      kitty_method = "normal";
      editor_only_render_when_focused = true;
      window_overlap_clear_enabled = true;
      max_width_window_percentage = 100;
      max_height_window_percentage = 50;
      integrations = {
        markdown.enabled = true;
        typst.enabled = true;
        html.enabled = true;
        css.enabled = true;
      };
      hijack_file_patterns = [
        "*.png"
        "*.jpg"
        "*.jpeg"
        "*.gif"
        "*.webp"
        "*.avif"
        "*.svg"
      ];
    };
  };
}
