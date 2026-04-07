{ ... }:

{
  programs.nixvim = {
    dependencies = {
      chafa.enable = true;
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

      extensions.fzf-native.enable = true;
    };

    extraConfigLua = ''
      local telescope_actions = require("telescope.actions")
      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<M-k>"] = telescope_actions.preview_scrolling_up,
              ["<M-j>"] = telescope_actions.preview_scrolling_down,
              ["<M-h>"] = telescope_actions.preview_scrolling_left,
              ["<M-l>"] = telescope_actions.preview_scrolling_right,
            },
            n = {
              ["<M-k>"] = telescope_actions.preview_scrolling_up,
              ["<M-j>"] = telescope_actions.preview_scrolling_down,
              ["<M-h>"] = telescope_actions.preview_scrolling_left,
              ["<M-l>"] = telescope_actions.preview_scrolling_right,
            },
          },
        },
      })
    '';
  };
}
