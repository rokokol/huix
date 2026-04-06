{ ... }:

{
  programs.nixvim = {
    dependencies = {
      chafa.enable = true;
      ffmpegthumbnailer.enable = true;
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
        preview.mime_hook.__raw = ''
          function(filepath, bufnr, opts)
            local preview_utils = require("telescope.previewers.utils")
            local image_extensions = {
              png = true,
              jpg = true,
              jpeg = true,
              webp = true,
              gif = true,
              avif = true,
              svg = true,
            }

            local extension = filepath:match("^.+%.([^.]+)$")
            extension = extension and extension:lower() or nil

            local function render_with_chafa(target)
              local width = 80
              local height = 40

              if opts.winid and vim.api.nvim_win_is_valid(opts.winid) then
                width = math.max(vim.api.nvim_win_get_width(opts.winid) - 2, 20)
                height = math.max(vim.api.nvim_win_get_height(opts.winid) - 2, 10)
              end

              local output = vim.fn.systemlist({
                "chafa",
                "--animate=off",
                "--center=on",
                "--clear",
                "--size",
                string.format("%dx%d", width, height),
                target,
              })

              if vim.v.shell_error ~= 0 then
                return false
              end

              vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, output)
              vim.bo[bufnr].modifiable = false
              vim.bo[bufnr].filetype = "text"
              return true
            end

            if extension and image_extensions[extension] then
              if not render_with_chafa(filepath) then
                preview_utils.set_preview_message(bufnr, opts.winid, "Image preview failed", opts.preview.msg_bg_fillchar)
              end
              return
            end

            if extension == "pdf" then
              local tmp_prefix = vim.fn.tempname()
              vim.fn.system({ "pdftoppm", "-png", "-singlefile", filepath, tmp_prefix })
              local png_preview = tmp_prefix .. ".png"

              if vim.v.shell_error == 0 and vim.fn.filereadable(png_preview) == 1 and render_with_chafa(png_preview) then
                return
              end

              preview_utils.set_preview_message(bufnr, opts.winid, "PDF preview failed", opts.preview.msg_bg_fillchar)
              return
            end

            preview_utils.set_preview_message(bufnr, opts.winid, "Binary cannot be previewed", opts.preview.msg_bg_fillchar)
          end
        '';
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
              "svg"
            ];
            find_cmd = "fd";
          };
        };
      };
    };
  };
}
