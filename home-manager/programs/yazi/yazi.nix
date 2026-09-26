{ pkgs, ... }:

# The nixpkgs wrapper already puts the stock previewers' tools on yazi's PATH (7zz, ffmpeg,
# poppler, imagemagick, chafa, resvg, fd, ripgrep, fzf, zoxide, jq, file)
{
  programs.yazi = {
    initLua = builtins.readFile ./init.lua;

    enable = true;
    enableZshIntegration = true;
    # `y` opens yazi and leaves the shell in the directory yazi was closed in
    shellWrapperName = "y";

    plugins = {
      inherit (pkgs.yaziPlugins)
        compress
        mime-ext
        mount
        piper
        ;
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

    # compress.yazi calls zip for a .zip; tar and its compressors come with the system. glow
    # renders Markdown for the previewer below
    extraPackages = with pkgs; [
      glow
      zip
    ];

    settings = {
      mgr = {
        sort_by = "natural";
        sort_dir_first = true;
        show_symlink = true;
      };

      # Markdown reads as rendered text rather than as source; piper hands glow the pane's
      # width and the terminal's light or dark scheme
      plugin.prepend_previewers = [
        {
          url = "*.md";
          run = ''piper -- CLICOLOR_FORCE=1 glow -w=$w -s=$t "$1"'';
        }
      ];

      # The type comes from the extension first and from file(1) only for an unknown one:
      # file(1) calls a zip whose first entries look like an office file's octet-stream, and
      # yazi then neither previews nor extracts it
      plugin.prepend_fetchers =
        map
          (side: {
            url = "${side}://*";
            run = "mime-ext.${side}";
            prio = "high";
            group = "mime";
          })
          [
            "local"
            "remote"
          ]
        ++
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
