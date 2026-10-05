{
  config,
  lib,
  pkgs,
  ...
}:

let
  # The clipboard and media helpers sit in the list where the rest do, so a desktop gets the
  # same PATH in the same order
  workstation = config.rokokol.workstation.enable;
in
{
  programs.nixvim = {
    extraPackages =
      with pkgs;
      [
        tree-sitter

        ripgrep
        fd
        bottom
        gdu
      ]
      ++ lib.optional workstation wl-clipboard
      ++ [
        gcc
        gnumake
        unzip
      ]
      ++ lib.optional workstation imagemagick # image.nvim processor
      ++ [
        file # mime detection for Telescope media search
      ]
      ++ lib.optionals workstation [
        ffmpeg # audio waveform preview
        ffmpegthumbnailer # video thumbnails for Telescope preview
      ]
      ++ [
        bat

        # Linters
        deadnix
        statix
        shellcheck
        nodejs
      ];
  };
}
