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
      local telescope_action_state = require("telescope.actions.state")

      local function huix_safe_preview_scroll(action, method)
        return function(prompt_bufnr)
          local picker = telescope_action_state.get_current_picker(prompt_bufnr)
          local previewer = picker and picker.previewer

          if previewer and previewer[method] then
            return action(prompt_bufnr)
          end
        end
      end

      local preview_up = huix_safe_preview_scroll(telescope_actions.preview_scrolling_up, "_scroll_fn")
      local preview_down = huix_safe_preview_scroll(telescope_actions.preview_scrolling_down, "_scroll_fn")
      local preview_left = huix_safe_preview_scroll(telescope_actions.preview_scrolling_left, "_scroll_horizontal_fn")
      local preview_right = huix_safe_preview_scroll(telescope_actions.preview_scrolling_right, "_scroll_horizontal_fn")

      require("telescope").setup({
        defaults = {
          mappings = {
            i = {
              ["<M-k>"] = preview_up,
              ["<M-j>"] = preview_down,
              ["<M-h>"] = preview_left,
              ["<M-l>"] = preview_right,
            },
            n = {
              ["<M-k>"] = preview_up,
              ["<M-j>"] = preview_down,
              ["<M-h>"] = preview_left,
              ["<M-l>"] = preview_right,
            },
          },
        },
      })
    '';
  };
}
