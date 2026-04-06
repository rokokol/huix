{ ... }:

{
  programs.nixvim = {
    plugins.project-nvim = {
      enable = true;
      enableTelescope = true;
      settings = {
        manual_mode = false;
        patterns = [
          ".git"
          "flake.nix"
          "package.json"
          "Cargo.toml"
          "pyproject.toml"
          "Makefile"
        ];
        show_hidden = true;
        silent_chdir = true;
        scope_chdir = "global";
      };
    };

    plugins.telescope.extensions.project = {
      enable = true;
      settings = {
        base_dirs.__raw = "nil";
        hidden_files = true;
        theme = "dropdown";
        order_by = "recent";
        search_by = "title";
        on_project_selected.__raw = "require('telescope._extensions.project.actions').find_project_files";
      };
    };
  };
}
