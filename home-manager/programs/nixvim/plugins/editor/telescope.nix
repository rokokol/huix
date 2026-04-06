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
        file_previewer.__raw = ''
          require("telescope.previewers").new_termopen_previewer({
            get_command = function(entry, status)
              local from_entry = require("telescope.from_entry")
              local filepath = from_entry.path(entry, true, false)

              if filepath == nil or filepath == "" then
                return nil
              end

              filepath = vim.fn.expand(filepath)

              if vim.fn.isdirectory(filepath) == 1 then
                return { "ls", "-la", filepath }
              end

              local extension = filepath:match("^.+%.([^.]+)$")
              extension = extension and extension:lower() or ""

              local image_extensions = {
                png = true,
                jpg = true,
                jpeg = true,
                webp = true,
                gif = true,
                avif = true,
                svg = true,
              }

              local width = 80
              local height = 40
              local preview_winid = status.layout.preview and status.layout.preview.winid

              if preview_winid and vim.api.nvim_win_is_valid(preview_winid) then
                width = math.max(vim.api.nvim_win_get_width(preview_winid) - 2, 20)
                height = math.max(vim.api.nvim_win_get_height(preview_winid) - 2, 10)
              end

              if image_extensions[extension] then
                return {
                  "chafa",
                  "--animate=off",
                  "--center=on",
                  "--clear",
                  "--size",
                  string.format("%dx%d", width, height),
                  filepath,
                }
              end

              if extension == "pdf" then
                return {
                  "bash",
                  "-lc",
                  [=[
                    tmp="$(mktemp -u)"
                    pdftoppm -png -singlefile -- "$1" "$tmp" >/dev/null 2>&1 && \
                      chafa --animate=off --center=on --clear --size "$2x$3" "$tmp.png"
                    rm -f "$tmp.png"
                  ]=],
                  "telescope-preview",
                  filepath,
                  tostring(width),
                  tostring(height),
                }
              end

              if vim.fn.executable("bat") == 1 then
                return {
                  "bat",
                  "--style=plain",
                  "--color=always",
                  "--paging=always",
                  "--",
                  filepath,
                }
              end

              return { "cat", "--", filepath }
            end,
          })
        '';
      };

      extensions.fzf-native.enable = true;
    };
  };
}
