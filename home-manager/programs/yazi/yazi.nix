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

    plugins = {
      inherit (pkgs.yaziPlugins) compress mount;
      # vim counts (5j, 3gg) and numbered lines as in nixvim: the hovered line shows its own
      # number, the others their distance from it
      relative-motions = {
        package = pkgs.yaziPlugins.relative-motions;
        setup = true;
        settings = {
          show_numbers = "relative_absolute";
          show_motion = true;
        };
      };
      # init.lua sets git up itself, since it wraps the column the plugin adds
      inherit (pkgs.yaziPlugins) git;
    };

    # compress.yazi calls zip for a .zip; tar and its compressors come with the system
    extraPackages = with pkgs; [ zip ];

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
