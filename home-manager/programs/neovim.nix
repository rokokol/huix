{ pkgs, ... }:

{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    viAlias = true;
    vimAlias = true;

    # For plugins support
    withNodeJs = true;
    withPython3 = true;

    plugins = with pkgs.vimPlugins; [
      nvim-treesitter-parsers.matlab
      gruvbox-nvim
      gruvbox-material-nvim
    ];

    extraPackages = with pkgs; [
      # --- 1. CORE TOOLS ---
      # For Mason & Telescope
      git
      lazygit
      ripgrep
      fd
      bottom
      gdu
      wl-clipboard

      # --- 2. COMPILERS & BUILD TOOLS ---
      gcc
      gnumake
      unzip
      gzip
      wget
      curl
      cargo # Rust package manager

      # --- 3. NIX ---
      nixd # LSP 
      nixpkgs-fmt # Formatter
      deadnix # Linter 
      statix # Linter 

      # --- 4. PYTHON ---
      ruff # Fast Linter 

      # --- 5. C / C++ ---
      clang-tools # clangd (LSP) & clang-format

      # --- 6. LUA ---
      matlab-language-server
      stylua # Formatter

      # --- 7. SHELL / BASH ---
      shfmt # Formatter для скриптов 
      shellcheck # Linter для bash 

      # --- 8. MATLAB ---
      matlab-language-server

      # --- 9. SYSTEM DEPENDENCIES ---
      tree-sitter
      nodejs
    ];
  };
}

