{ base16, lib, ... }:

{
  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    # --- Globals ---
    diagnostic.settings = {
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
      updatetime = 250;
    };

    # --- Appearance ---
    colorschemes.base16 = {
      enable = true;
      colorscheme = base16.dark;
    };

    # base16-nvim paints every ground with base00 and has no transparency switch, so kitty's
    # background_opacity only shows through once those are cleared. Sweeping by colour rather
    # than by group name keeps gutters and floats in step: naming a few left the rest opaque
    # around a transparent text area, which reads as a half-painted window
    extraConfigLuaPost = ''
      local ground = tonumber("${lib.removePrefix "#" base16.dark.base00}", 16)
      for group, hl in pairs(vim.api.nvim_get_hl(0, {})) do
        if hl.bg == ground then
          hl.bg = "NONE"
          vim.api.nvim_set_hl(0, group, hl)
        end
      end
    '';

    # --- Lua Config ---
    extraConfigLua = ''
      local disabled_built_ins = {
        "netrw", "netrwPlugin", "netrwSettings", "netrwFileHandlers",
        "gzip", "zip", "zipPlugin", "tar", "tarPlugin", "tohtml"
      }
      for _, plugin in ipairs(disabled_built_ins) do
        vim.g["loaded_" .. plugin] = 1
      end

      -- LazyGit Close Fix for Terminal
      vim.api.nvim_create_autocmd("TermOpen", {
        pattern = "term://*",
        callback = function()
          local opts = {buffer = 0}
          vim.keymap.set('t', '<Esc><Esc>', [[<C-\><C-n>]], opts)
          vim.keymap.set('t', '<C-h>', [[<C-\><C-n><C-w>h]], opts)
          vim.keymap.set('t', '<C-j>', [[<C-\><C-n><C-w>j]], opts)
          vim.keymap.set('t', '<C-k>', [[<C-\><C-n><C-w>k]], opts)
          vim.keymap.set('t', '<C-l>', [[<C-\><C-n><C-w>l]], opts)
        end,
      })
    '';
  };
}
