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
      max_height_window_percentage = 100;
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

  programs.nixvim.extraConfigLua = ''
    local function huix_get_current_hijacked_image()
      local ok, image_api = pcall(require, "image")

      if not ok then
        return nil
      end

      local images = image_api.get_images({
        window = vim.api.nvim_get_current_win(),
        buffer = vim.api.nvim_get_current_buf(),
      })

      return images[1]
    end

    _G.HuixImageZoom = _G.HuixImageZoom or function(multiplier)
      local image = huix_get_current_hijacked_image()

      if not image then
        return
      end

      image.ignore_global_max_size = true
      image.max_width_window_percentage = nil
      image.max_height_window_percentage = nil

      local base_width = image.geometry.width or (image.rendered_geometry and image.rendered_geometry.width) or 1
      local base_height = image.geometry.height or (image.rendered_geometry and image.rendered_geometry.height) or 1

      image:render({
        width = math.max(1, math.floor(base_width * multiplier + 0.5)),
        height = math.max(1, math.floor(base_height * multiplier + 0.5)),
      })
    end

    _G.HuixImageZoomReset = _G.HuixImageZoomReset or function()
      local image = huix_get_current_hijacked_image()

      if not image then
        return
      end

      image.ignore_global_max_size = false
      image.max_width_window_percentage = nil
      image.max_height_window_percentage = nil
      image.geometry.width = nil
      image.geometry.height = nil
      image:clear()
      image:render()
    end

    _G.HuixImagePan = _G.HuixImagePan or function(delta_y)
      local image = huix_get_current_hijacked_image()

      if not image then
        return
      end

      local current_x = image.geometry.x or 0
      local current_y = image.geometry.y or 1
      local rendered_height = (image.rendered_geometry and image.rendered_geometry.height) or image.geometry.height or 1
      local min_y = math.min(1, 2 - rendered_height)
      local max_y = 1
      local next_y = math.max(min_y, math.min(max_y, current_y + delta_y))

      image:move(current_x, next_y)
    end

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "image_nvim",
      callback = function(event)
        local opts = { buffer = event.buf, silent = true }

        vim.keymap.set("n", "+", function()
          _G.HuixImageZoom(1.25)
        end, opts)

        vim.keymap.set("n", "=", function()
          _G.HuixImageZoom(1.25)
        end, opts)

        vim.keymap.set("n", "-", function()
          _G.HuixImageZoom(0.8)
        end, opts)

        vim.keymap.set("n", "0", function()
          _G.HuixImageZoomReset()
        end, opts)

        vim.keymap.set("n", "j", function()
          _G.HuixImagePan(-3)
        end, opts)

        vim.keymap.set("n", "k", function()
          _G.HuixImagePan(3)
        end, opts)

        vim.keymap.set("n", "<Down>", function()
          _G.HuixImagePan(-3)
        end, opts)

        vim.keymap.set("n", "<Up>", function()
          _G.HuixImagePan(3)
        end, opts)
      end,
    })
  '';
}
