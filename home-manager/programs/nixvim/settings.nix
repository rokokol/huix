{ ... }:

{
  programs.nixvim = {
    # --- Globals ---
    diagnostics = {
      underline = false;
      virtual_text = false;
    };
    globals = {
      mapleader = " ";
      maplocalleader = ",";
    };
    # --- Options ---
    opts = {
      confirm = true;
      number = true;
      relativenumber = true;
      shiftwidth = 2;
      tabstop = 2;
      expandtab = true;
      smartindent = true;
      termguicolors = true;
      cursorline = true;
      scrolloff = 8;
      timeoutlen = 300;

      pumheight = 10;
      pumblend = 0;
      winblend = 0;

      undofile = true;
      undodir = {
        __raw = "vim.fn.stdpath('data') .. '/undo'";
      };
      undoreload = 1000;
      undolevels = 1000;

      clipboard = "unnamedplus";
      # Russian layout support for commands
      langmap = "ФИСВУАПРШОЛДЬТЩЗЙКЫЕГМЦЧНЯ;ABCDEFGHIJKLMNOPQRSTUVWXYZ,фисвуапршолдьтщзйкыегмцчня;abcdefghijklmnopqrstuvwxyz";
      updatetime = 250;
    };

    # --- Appearance ---
    colorschemes.gruvbox = {
      enable = true;
      settings = {
        transparent_mode = true;
        overrides = {
          NormalFloat.bg = "none";
          FloatBorder.bg = "none";
          Pmenu.bg = "none";
          TelescopeNormal.bg = "none";
          TelescopeBorder.bg = "none";
          WhichKeyFloat.bg = "none";
        };
      };
    };

    # --- Lua Config ---
    extraConfigLua = ''
      local disabled_built_ins = {
        "netrw", "netrwPlugin", "netrwSettings", "netrwFileHandlers",
        "gzip", "zip", "zipPlugin", "tar", "tarPlugin", "tohtml"
      }
      for _, plugin in ipairs(disabled_built_ins) do
        vim.g["loaded_" .. plugin] = 1
      end

      _G.HuixTelescopeFilePreviewer = _G.HuixTelescopeFilePreviewer or function()
        local previewers = require("telescope.previewers")
        local from_entry = require("telescope.from_entry")

        return previewers.new_termopen_previewer({
          get_command = function(entry, status)
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
                [[
                  tmp="$(mktemp -u)"
                  pdftoppm -png -singlefile -- "$1" "$tmp" >/dev/null 2>&1 && \
                    chafa --animate=off --center=on --clear --size "$2x$3" "$tmp.png"
                  rm -f "$tmp.png"
                ]],
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
      end

      -- LazyGit Close Fix for Terminal
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*",
        callback = function()
          local opts = {buffer = 0}
          -- vim.keymap.set('t', '<Esc>', [[<C-\><C-n>]], opts)
          vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], opts)
          vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], opts)
          vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], opts)
          vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], opts)
        end,
      })
    '';
  };
}
