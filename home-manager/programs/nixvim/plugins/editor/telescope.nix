{ ... }:

{
  imports = [ ./telescope-helpers.nix ];

  programs.nixvim = {
    dependencies = {
      chafa.enable = true;
      poppler-utils.enable = true;
    };

    plugins.telescope = {
      enable = true;
      settings.defaults =
        let
          # i и n делят один набор скролл-биндов превью.
          scrollMappings = {
            "<M-k>".__raw = "require('telescope.actions').preview_scrolling_up";
            "<M-j>".__raw = "require('telescope.actions').preview_scrolling_down";
            "<M-h>".__raw = "require('telescope.actions').preview_scrolling_left";
            "<M-l>".__raw = "require('telescope.actions').preview_scrolling_right";
          };
        in
        {
          layout_strategy = "vertical";
          layout_config = {
            vertical = {
              mirror = true;
              prompt_position = "top";
              preview_height = 0.5;
            };
          };
          mappings = {
            i = scrollMappings;
            n = scrollMappings;
          };
        };

      extensions.fzf-native.enable = true;
    };
  };
}
