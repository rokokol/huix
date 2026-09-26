{
  lib,
  pkgs,
  ruLayout,
  ...
}:

# The nixpkgs wrapper already puts the stock previewers' tools on yazi's PATH (7zz, ffmpeg,
# poppler, imagemagick, chafa, resvg, fd, ripgrep, fzf, zoxide, jq, file)
let
  layout = lib.listToAttrs (map (p: lib.nameValuePair p.en p.ru) ruLayout);
in
{
  programs.yazi = {
    initLua = ''
      RU_LAYOUT = ${lib.generators.toLua { } layout}
    ''
    + builtins.readFile ./init.lua;

    enable = true;
    enableZshIntegration = true;
    # `y` opens yazi and leaves the shell in the directory yazi was closed in
    shellWrapperName = "y";

    # init.lua sets git up itself, since it wraps the column the plugin adds
    plugins.git = pkgs.yaziPlugins.git;

    settings = {
      mgr = {
        sort_by = "natural";
        sort_dir_first = true;
        show_symlink = true;
      };

      plugin.prepend_fetchers =
        map
          (url: {
            inherit url;
            run = "git";
            group = "git";
          })
          [
            "*"
            "*/"
          ];
    };
  };
}
