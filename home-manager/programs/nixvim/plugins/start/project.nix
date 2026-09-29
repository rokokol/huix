_:

{
  programs.nixvim = {
    plugins.project-nvim = {
      enable = true;
      enableTelescope = true;
      settings = {
        # The plugin's own BufEnter hook changes the working directory in the same call that records
        # the project, so it stays off and the hook below records the project alone
        manual_mode = true;
        patterns = [
          ".git"
          "flake.nix"
          "package.json"
          "Cargo.toml"
          "pyproject.toml"
          "Makefile"
        ];
        show_hidden = false;
        silent_chdir = true;
        scope_chdir = "global";
      };
    };

    # The plugin writes the session list to its history file on exit, so the picker still learns
    # every project opened here
    autoCmd = [
      {
        event = "BufEnter";
        callback.__raw = ''
          function(ev)
            local core = require("project.core")
            local disabled_ft = require("project.config").get().disable_on.ft
            if
              not core.valid_bt(ev.buf)
              or vim.api.nvim_buf_get_name(ev.buf) == ""
              or vim.list_contains(disabled_ft, vim.bo[ev.buf].filetype)
            then
              return
            end

            local root = core.get_project_root(ev.buf)
            if not root or require("project.util").path.is_excluded(root) then
              return
            end

            local history = require("project.util.history")
            local sessions = history.get_session_projects()
            for _, entry in ipairs(sessions) do
              if entry.path == root then
                return
              end
            end

            table.insert(sessions, 1, {
              path = root,
              name = history.find_entry("recent", root, "name")
                or vim.fn.fnamemodify(root, ":h:t") .. "/" .. vim.fn.fnamemodify(root, ":t"),
            })
            history.set_session_projects(sessions)
          end
        '';
      }
    ];
  };
}
