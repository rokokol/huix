{ ... }:

{
  programs.nixvim = {
    keymaps = [
      # --- UI ---
      {
        mode = "n";
        key = "<leader>uw";
        action = ":set wrap!<CR>";
        options.desc = "Toggle Word Wrap";
      }
      {
        mode = "n";
        key = "<leader>uv";
        action = ":vsplit<CR>";
        options.desc = "Vertical Split";
      }
      {
        mode = "n";
        key = "<leader>uh";
        action = ":split<CR>";
        options.desc = "Horizontal Split";
      }
      {
        mode = "n";
        key = "<leader>e";
        action = ":Neotree toggle<CR>";
        options.desc = "Toggle Explorer";
      }
      {
        mode = "n";
        key = "<leader>ui";
        action.__raw = "function() require('image').clear() end";
        options.desc = "Clear Images";
      }

      # --- Find (Telescope) ---
      {
        mode = "n";
        key = "<leader>ff";
        action = ":Telescope find_files<CR>";
        options.desc = "Find Files";
      }
      {
        mode = "n";
        key = "<leader>fg";
        action = ":Telescope live_grep<CR>";
        options.desc = "Live Grep";
      }
      {
        mode = "n";
        key = "<leader>fb";
        action = ":Telescope buffers<CR>";
        options.desc = "Find Buffers";
      }
      {
        mode = "n";
        key = "<leader>fw";
        action = ":Telescope grep_string<CR>";
        options.desc = "Grep Word under cursor";
      }
      {
        # bufnr=0 ensures search in current file only
        mode = "n";
        key = "<leader>fe";
        action = "<cmd>Telescope diagnostics bufnr=0<CR>";
        options.desc = "Buffer Diagnostics";
      }
      {
        mode = "n";
        key = "<leader>fs";
        action.__raw = "function() require('telescope.builtin').lsp_document_symbols({ symbols = {'Function', 'Method', 'Class', 'Struct'} }) end";
        options.desc = "Document Symbols";
      }
      {
        mode = "n";
        key = "<leader>fa";
        action.__raw = ''function() require('telescope.builtin').find_files({ cwd = "/home/rokokol/huix/", prompt_title = "Nix Config" }) end'';
        options.desc = "Find Nix Config";
      }
      {
        mode = "n";
        key = "<leader>fl";
        action = ":Telescope current_buffer_fuzzy_find<CR>";
        options.desc = "Find inside file";
      }

      # --- LSP ---
      {
        mode = "n";
        key = "<leader>la";
        action = "<cmd>Lspsaga code_action<CR>";
        options.desc = "Code Action";
      }
      {
        mode = "n";
        key = "<leader>lr";
        action = "<cmd>Lspsaga rename<CR>";
        options.desc = "Rename";
      }
      {
        mode = "n";
        key = "<leader>le";
        action = "<cmd>Lspsaga show_line_diagnostics<CR>";
        options.desc = "Show Line Error";
      }
      {
        mode = "n";
        key = "<leader>ld";
        action = "<cmd>Lspsaga peek_definition<CR>";
        options.desc = "Peek Definition";
      }
      {
        mode = "n";
        key = "<leader>l?";
        action = "<cmd>Lspsaga hover_doc<CR>";
        options.desc = "Hover Doc / Signature";
      }
      {
        mode = "n";
        key = "<leader>ll";
        action.__raw = ''
          function()
            local current_state = vim.diagnostic.config().virtual_lines
            vim.diagnostic.config({ virtual_lines = not current_state })
          end
        '';
        options = {
          desc = "Toggle LSP Lines";
          silent = true;
        };
      }
      {
        mode = "n";
        key = "<leader>w";
        action.__raw = "function() vim.lsp.buf.format({ async = false }) vim.cmd('w') end";
        options.desc = "Format & Save";
      }
      {
        mode = "n";
        key = "<leader>lf";
        action.__raw = "function() vim.lsp.buf.format({ async = true }) end";
        options.desc = "Format Buffer";
      }

      # --- Git ---
      {
        mode = "n";
        key = "<leader>gg";
        action = ":LazyGit<CR>";
        options.desc = "LazyGit UI";
      }
      {
        mode = "n";
        key = "<leader>gb";
        action = ":Gitsigns toggle_current_line_blame<CR>";
        options.desc = "Toggle Blame";
      }

      # --- Terminals ---
      {
        mode = "n";
        key = "<leader>tf";
        action = ":ToggleTerm direction=float<CR>";
        options.desc = "Float Term";
      }
      {
        mode = "n";
        key = "<leader>tv";
        action = ":ToggleTerm direction=vertical size=60<CR>";
        options.desc = "Vertical Term";
      }
      {
        mode = "n";
        key = "<leader>th";
        action = ":ToggleTerm direction=horizontal<CR>";
        options.desc = "Horizontal Term";
      }

      # --- Buffer Management ---
      {
        mode = "n";
        key = "<leader>c";
        action.__raw = ''
          function()
            local bufnr = vim.api.nvim_get_current_buf()
            vim.cmd("bprevious")
            if vim.api.nvim_get_current_buf() == bufnr then
              vim.cmd("enew")
            end
            vim.cmd("bdelete " .. bufnr)
          end
        '';
        options.desc = "Close Buffer";
      }
      {
        mode = "n";
        key = "<leader>C";
        action = "<cmd>BufferLineCloseOthers<cr>";
        options = {
          silent = true;
          desc = "Close Unactive Buffers";
        };
      }
      {
        mode = "n";
        key = "<leader>d";
        action = ":cd %:p:h | pwd<CR>";
        options.desc = "Global CD to Buffer";
      }

      {
        mode = "n";
        key = "<leader>bb";
        action = "<cmd>BufferLinePick<cr>";
        options = {
          desc = "Pick the Buffer";
          silent = true;
        };
      }

      # --- Editing & Navigation ---
      {
        mode = "n";
        key = "<A-j>";
        action = ":m .+1<CR>==";
      }
      {
        mode = "n";
        key = "<A-k>";
        action = ":m .-2<CR>==";
      }
      {
        mode = "v";
        key = "<A-j>";
        action = ":m '>+1<CR>gv=gv";
      }
      {
        mode = "v";
        key = "<A-k>";
        action = ":m '<-2<CR>gv=gv";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "d";
        action = "\"_d";
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "D";
        action = "\"_D";
      }
      {
        mode = "v";
        key = "p";
        action = "\"_dP";
      }
      {
        mode = "v";
        key = "<Tab>";
        action = ">gv";
      }
      {
        mode = "v";
        key = "<S-Tab>";
        action = "<gv";
      }
      {
        mode = "n";
        key = "<Tab>";
        action = ":bnext<CR>";
      }
      {
        mode = "n";
        key = "<S-Tab>";
        action = ":bprev<CR>";
      }
      # Window navigation
      {
        mode = "n";
        key = "<C-h>";
        action = "<C-w>h";
      }
      {
        mode = "n";
        key = "<C-j>";
        action = "<C-w>j";
      }
      {
        mode = "n";
        key = "<C-k>";
        action = "<C-w>k";
      }
      {
        mode = "n";
        key = "<C-l>";
        action = "<C-w>l";
      }

      {
        mode = "n";
        key = "<esc>";
        action = ":nohlsearch<cr>";
      }
      {
        mode = "n";
        key = "L";
        action = "<C-i>";
        options = {
          desc = "Jump forward";
        };
      }
      {
        mode = "n";
        key = "H";
        action = "<C-o>";
        options = {
          desc = "Jump backward";
        };
      }

    ];
  };
}
