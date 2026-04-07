{ ... }:

{
  programs.nixvim = {
    plugins.project-nvim = {
      enable = true;
      enableTelescope = true;
      settings = {
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
  };
}
