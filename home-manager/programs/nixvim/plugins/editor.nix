{ ... }:

{
  programs.nixvim.plugins = {
    # File Explorer
    neo-tree = {
      enable = true;
      settings = {
        filesystem = {
          bind_to_cwd = true;
          follow_current_file.enabled = true;
          use_libuv_file_watcher = true;
        };

        commands = {
          system_open = {
            __raw = ''
              function(state)
                 local node = state.tree:get_node()
                 local path = node:get_id()
                 
                 vim.fn.jobstart({"xdg-open", path}, {detach = true})
               end
            '';
          };

          copy_path = {
            __raw = ''
              function(state)
                local node = state.tree:get_node()
                local path = node:get_id()
                vim.fn.setreg("+", path)
                vim.notify("Path yanked: " .. path)
              end
            '';
          };
        };

        window = {
          width = 30;
          auto_expand_width = false;
          position = "left";
          mappings = {
            "O" = "system_open";
            "Y" = "copy_path";
          };
        };

        default_component_configs = {
          icon = {
            folder_closed = "";
            folder_open = "";
            folder_empty = "";
            default = "";
            highlight = "NeoTreeFileIcon";
          };
          modified = {
            symbol = "[+]";
            highlight = "NeoTreeModified";
          };
          git_status = {
            symbols = {
              added = "";
              modified = "";
              deleted = "";
              renamed = "";
              untracked = "";
              ignored = "";
              unstaged = "󰄱";
              staged = "";
              conflict = "";
            };
          };
          diagnostics = {
            symbols = {
              hint = "";
              info = "";
              warn = "";
              error = "";
            };
            highlights = {
              hint = "DiagnosticSignHint";
              info = "DiagnosticSignInfo";
              warn = "DiagnosticSignWarn";
              error = "DiagnosticSignError";
            };
          };
        };
      };
    };

    # Fuzzy Finder
    telescope = {
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

    # Parsing & Highlighting
    treesitter = {
      enable = true;
      nixGrammar = true;
      settings = {
        indent.enable = true;
        highlight.enable = true;
        ensure_installed = [
          "markdown"
          "markdown_inline"
          "bash"
          "css"
          "html"
          "hyprlang"
          "json"
        ];
      };
    };

    # Git
    gitsigns.enable = true;
    lazygit.enable = true;

    # Keymaps Popup
    which-key = {
      enable = true;
      settings = {
        win.border = "rounded";
        spec = [
          {
            __unkeyed = "<leader>f";
            group = "Find";
          }
          {
            __unkeyed = "<leader>g";
            group = "Git";
          }
          {
            __unkeyed = "<leader>l";
            group = "LSP";
          }
          {
            __unkeyed = "<leader>t";
            group = "Terminals";
          }
          {
            __unkeyed = "<leader>u";
            group = "UI";
          }
        ];
      };
    };

    # Terminal
    toggleterm = {
      enable = true;
      settings = {
        open_mapping = "[[<C-t>]]";
        float_opts.border = "curved";
      };
    };

    # Mini
    mini = {
      enable = true;
      modules = {
        icons = { };
      };
      mockDevIcons = true;
    };

    # Session Management
    persistence.enable = true;
  };
}
