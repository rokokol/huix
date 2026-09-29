{ pkgs, whichKeyDelay, ... }:

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
        chmod
        compress
        mime-ext
        mount
        piper
        sudo
        toggle-pane
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
    # renders Markdown for the previewer below. sudo.yazi runs its file operations as a nu
    # script, and sudo keeps the caller's PATH, as no secure_path is set
    extraPackages = with pkgs; [
      glow
      nushell
      zip
    ];

    settings = {
      mgr = {
        # touch is horizontal scrolling, which init.lua turns into h and l
        mouse_events = [
          "click"
          "scroll"
          "touch"
          "drag"
        ];
        sort_by = "natural";
        sort_dir_first = true;
        show_symlink = true;
      };

      # The which popup folds each leader group under its label from keymap.nix and waits as
      # long as nixvim's which-key does; both options come from patches in flake.nix
      which = {
        fold = true;
        delay = whichKeyDelay / 1000.0;
      };

      # The stock text/* rule offers only the editor; Enter keeps it, and the Shift+Enter menu
      # gains xdg-open, so an HTML page can still reach the browser
      open.prepend_rules = [
        {
          mime = "text/*";
          use = [
            "edit"
            "open"
            "reveal"
          ];
        }
      ];

      # Markdown reads as rendered text rather than as source; piper hands glow the pane's
      # width and the terminal's light or dark scheme
      plugin.prepend_previewers = [
        {
          url = "*.md";
          run = ''piper -- CLICOLOR_FORCE=1 glow -w=$w -s=$t "$1"'';
        }
        # A picture over its details: a video's frame, an audio file's spectrogram, an image.
        # No preloader makes the spectrogram ahead: it decodes the whole track, and a folder
        # of an album would cost a minute of CPU for pictures nobody asked for
        {
          mime = "{audio,video,image}/*";
          run = "info";
        }
      ];

      # One spotter for every file; it hands the virtual ones back to yazi's own
      plugin.prepend_spotters =
        map
          (url: {
            inherit url;
            run = "info";
          })
          [
            "*"
            "*/"
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
