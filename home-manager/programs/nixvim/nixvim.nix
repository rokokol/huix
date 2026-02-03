{ pkgs, ... }:
{
  # Import all modules
  imports = [
    ./settings.nix
    ./keymaps.nix
    ./plugins/default.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    # System packages required for plugins and tools
    extraPackages = with pkgs; [
      ripgrep
      fd
      bottom
      gdu
      wl-clipboard
      gcc
      gnumake
      unzip
      imagemagick
      ffmpegthumbnailer # Video previews
      chafa # Image fallback
      poppler-utils # PDF previews

      # LSPs and Formatters
      nixd
      nixfmt
      deadnix
      statix
      ruff
      black
      pyright
      clang-tools
      stylua
      shfmt
      shellcheck
      nodejs
      lua-language-server
      bash-language-server
    ];
  };
}
