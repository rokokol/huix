_:

# The nixpkgs wrapper already puts the stock previewers' tools on yazi's PATH (7zz, ffmpeg,
# poppler, imagemagick, chafa, resvg, fd, ripgrep, fzf, zoxide, jq, file)
{
  programs.yazi = {
    enable = true;
    enableZshIntegration = true;
    # `y` opens yazi and leaves the shell in the directory yazi was closed in
    shellWrapperName = "y";

    settings.mgr = {
      sort_by = "natural";
      sort_dir_first = true;
      show_symlink = true;
    };
  };
}
