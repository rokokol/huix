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

      # Linters
      deadnix
      statix
      shellcheck
      nodejs
    ];
  };
}
