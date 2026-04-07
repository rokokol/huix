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
              ["<C-k>"] = telescope_actions.preview_scrolling_up,
              ["<C-j>"] = telescope_actions.preview_scrolling_down,
            },
            n = {
              ["K"] = telescope_actions.preview_scrolling_up,
              ["J"] = telescope_actions.preview_scrolling_down,
            },
          },
        },
      })
    '';
  };
}
