{ ... }:

{
  programs.nixvim = {
    dependencies = {
      chafa.enable = true;
      epub-thumbnailer.enable = true;
      ffmpegthumbnailer.enable = true;
      fontpreview.enable = true;
      poppler-utils.enable = true;
    };

    plugins.telescope = {
      enable = true;
      settings.defaults = {
        layout_strategy = "vertical";
        layout_config = {
          vertical = {
            mirror = true;
            prompt_position = "top";
            preview_height = 0.5;
          };
        };
      };

      extensions = {
        fzf-native.enable = true;
        media-files = {
          enable = true;
          settings = {
            filetypes = [
              "png"
              "jpg"
              "jpeg"
              "webp"
              "gif"
              "avif"
              "mp4"
              "webm"
              "pdf"
              "epub"
            ];
            find_cmd = "fd";
          };
        };
      };
    };
  };
}
