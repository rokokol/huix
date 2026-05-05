{ pkgs, ... }:

{
  programs.nixvim = {
    extraPackages = with pkgs; [
      tree-sitter

      ripgrep
      fd
      bottom
      gdu
      wl-clipboard
      gcc
      gnumake
      unzip
      imagemagick # image.nvim processor
      file # mime detection for Telescope media search
      ffmpeg # audio waveform preview
      ffmpegthumbnailer # video thumbnails for Telescope preview
      bat

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
