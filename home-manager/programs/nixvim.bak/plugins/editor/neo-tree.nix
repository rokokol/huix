{ ... }:

{
  programs.nixvim.plugins.neo-tree = {
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
}
