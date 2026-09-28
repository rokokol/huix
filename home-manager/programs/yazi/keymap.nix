{
  config,
  lib,
  pkgs,
  ruLayout,
  ...
}:

# Bindings on top of yazi's stock keymap, which stays in force below them. Groups hang off the
# same leader as in nixvim; a chord placed first shadows a stock one that starts with the same
# key, which is how <Space>, <Tab> and `m` change their meaning here. The langmap turns a key
# typed in the Russian layout into the Latin one on the same place before any of this matches
let
  # `leader "fg"` is <Space> f g: one character per key
  leader = keys: [ "<Space>" ] ++ lib.stringToCharacters keys;

  bind = on: run: desc: { inherit on run desc; };

  # A chord without `run` names the leader group its keys open, for the which popup to fold
  # the group under (patches/yazi-which-groups.patch); the names follow nixvim's where the
  # groups match
  label = keys: desc: {
    on = leader keys;
    inherit desc;
  };

  labels = lib.mapAttrsToList label {
    a = "Archive";
    f = "Find";
    g = "Git";
    n = "Name";
    s = "Sort";
    t = "Terminals";
    u = "UI";
    x = "Tools";
    xs = "As root";
  };

  # Each Russian character against the Latin key it sits on
  langmap = lib.listToAttrs (map (p: lib.nameValuePair p.ru p.en) ruLayout);

  # A plugin reads only the committed selection, and a visual range is committed on its way out
  # of visual mode, so the range goes first, as yazi's own copy, shell and rename do
  onSelection = run: [
    "escape --visual"
    run
  ];

  # A yank also goes to the system clipboard, and an unyank takes it back from there
  exported = run: [
    run
    "plugin clipboard-sync export"
  ];

  ownPlugin =
    name:
    builtins.path {
      name = "yazi-${name}";
      path = ./plugins/${name};
      # a plugin's test runs in the flake's checks and has no business in yazi's config
      filter = path: _: baseNameOf path != "test.lua";
    };

  # A lower-case key sorts one way and its upper-case twin the other, as in the stock `,` group.
  # The three fields a linemode can show switch the linemode with them
  sorts = {
    n = {
      by = "natural";
    };
    a = {
      by = "alphabetical";
    };
    m = {
      by = "mtime";
      linemode = "mtime";
    };
    b = {
      by = "btime";
      linemode = "btime";
    };
    e = {
      by = "extension";
    };
    s = {
      by = "size";
      linemode = "size";
    };
  };

  sortBinds = lib.concatLists (
    lib.mapAttrsToList (
      key: s:
      let
        run =
          reverse:
          [ "sort ${s.by} --reverse=${reverse}" ] ++ lib.optional (s ? linemode) "linemode ${s.linemode}";
      in
      [
        (bind (leader "s${key}") (run "no") "Sort by ${s.by}")
        (bind (leader "s${lib.toUpper key}") (run "yes") "Sort by ${s.by}, reversed")
      ]
    ) sorts
  );

  linemodes = {
    s = "size";
    p = "permissions";
    o = "owner";
    m = "mtime";
    b = "btime";
    n = "none";
  };

  # The bookmarks Thunar's side pane shows, beside yazi's own `g h`, `g d` and `g t`. The which
  # panel cuts a description short, so it is the folder alone
  bookmarkBinds = map (
    b:
    bind [ "g" b.key ] "cd ${lib.escapeShellArg b.path}" (
      lib.replaceStrings [ config.home.homeDirectory ] [ "~" ] b.path
    )
  ) (lib.filter (b: b.key != null) config.rokokol.bookmarks);

  linemodeBinds = lib.mapAttrsToList (
    key: mode: bind (leader "u${key}") "linemode ${mode}" "Show ${mode}"
  ) linemodes;
in
{
  programs.yazi = {
    extraPackages = with pkgs; [
      archivemount
      fuse-archive
      libnotify
      ripgrep-all
    ];

    plugins =
      lib.genAttrs [
        "find-line"
        "search-ignored"
        "git-column"
        "naming"
        "nvim-diff"
        "recent"
        "tab-hovered"
      ] ownPlugin
      // {
        # The spot window on `I`. compsize runs through sudo, and nixos/btrfs.nix allows exactly
        # this path without a password; off btrfs, du gives the size on disk
        info = {
          package = ownPlugin "info";
          setup = true;
          settings.compsize = lib.getExe pkgs.compsize;
        };
        # wl-clipboard-rs carries the --offer patch (see WORKAROUNDS.md)
        clipboard-sync = {
          package = ownPlugin "clipboard-sync";
          setup = true;
          settings.wl_clipboard = "${pkgs.wl-clipboard-rs}/bin";
        };
        # setup subscribes to cd, which unmounts the archives no tab looks into
        archive-mount = {
          package = ownPlugin "archive-mount";
          setup = true;
        };
      };

    keymap = { inherit langmap; };

    # The spot has nothing else on `c`, so the value under the cursor is copied without the
    # stock second press
    keymap.spot.prepend_keymap = [ (bind "c" "copy cell" "Copy the value") ];

    # A digit starts a count for relative-motions; tabs switch on <Tab> instead
    keymap.mgr.prepend_keymap =
      map (n: bind (toString n) "plugin relative-motions ${toString n}" "Count ${toString n}") (
        lib.range 1 9
      )
      ++ [
        (bind "m" [ "toggle" "arrow 1" ] "Toggle selection")
        (bind "M" "toggle_all --state=on" "Select all")
        (bind "<Tab>" "tab_switch 1 --relative" "Next tab")
        (bind "<S-Tab>" "tab_switch -1 --relative" "Previous tab")
        (bind "T" "plugin tab-hovered" "Hovered directory in a new tab")
        (bind "y" (exported "yank") "Copy, to the system clipboard too")
        (bind "x" (exported "yank --cut") "Cut, to the system clipboard too")
        # Beside the stock `c` group, which copies paths and names; wl-copy takes the type from
        # the content, so an image goes as an image
        (bind [
          "c"
          "t"
        ] "shell '${pkgs.wl-clipboard-rs}/bin/wl-copy < %h'" "Copy the file's contents")
        (bind "Y" (exported "unyank") "Cancel the copy or cut")
        (bind "X" (exported "unyank") "Cancel the copy or cut")
        # y and x put the files on the system clipboard as well, so one paste reads it all:
        # yazi's own yank, other programs' files, an image or a text
        (bind "p" "plugin clipboard-sync paste" "Paste the clipboard")
        (bind "P" "plugin clipboard-sync 'paste --force'" "Paste the clipboard, overwriting")
        (bind "I" "spot" "File info")
        (bind "e" "shell --block 'nvim %s'" "Open in nvim here")
        (bind "E" "shell --orphan 'kitty --detach nvim %s'" "Open in nvim in a new window")

        (bind (leader "c") "close" "Close tab")
        (bind (leader "nr") "rename --cursor=before_ext" "Rename, several at once in nvim")
        (bind (leader "nc") (onSelection "plugin naming kebab") "kebab-case")
        (bind (leader "ns") (onSelection "plugin naming snake") "snake_case")
        (bind (leader "nC") (onSelection "plugin naming caps") "CAPS_CASE")
        (bind (leader "np") (onSelection "plugin naming pascal") "PascalCase")
        (bind (leader "nm") (onSelection "plugin naming camel") "camelCase")
        (bind (leader "nt") (onSelection "plugin naming icao") "Transliterate Cyrillic (ICAO)")

        # The searches skip what a .gitignore names until Space f i lets them in; the switch sits
        # with them, as only a search reads it. rga reads plain text as rg does, and pdf and
        # office files besides. Esc cancels a search, as the stock keymap has it
        (bind (leader "ff") "plugin search-ignored names" "Find names")
        (bind (leader "fg") "plugin search-ignored content" "Find content, pdf and office too")
        (bind (leader "fi") "plugin search-ignored toggle" "Ignored files in searches")
        (bind (leader "fz") "plugin zoxide" "Jump via zoxide")
        (bind (leader "fs") "plugin fzf" "Jump via fzf")
        (bind (leader "fl") "plugin find-line" "Find a line in the hovered file")

        (bind (leader "uh") "hidden toggle" "Hidden files")
        (bind (leader "ug") "plugin git-column" "Git status column")
        (bind (leader "uv") "plugin toggle-pane min-preview" "Preview pane")
        (bind (leader "uV") "plugin toggle-pane max-preview" "Preview pane, full width")
        (bind (leader "uP") "plugin toggle-pane min-parent" "Parent pane")

        (bind (leader "gg") "shell --block lazygit" "LazyGit")

        # compress.yazi asks for the archive's name and suggests one
        (bind (leader "az") (onSelection "plugin compress zip") "Pack into zip")
        (bind (leader "at") (onSelection "plugin compress tar.gz") "Pack into tar.gz")
        (bind (leader "a7") (onSelection "plugin compress 7z") "Pack into 7z")
        (bind (leader "ap") (onSelection "plugin compress '-ph 7z'") "Pack into 7z with a password")
        (bind (leader "ax") "shell 'ya pub extract --list %s'" "Extract here")
        (bind (leader "ao") "plugin archive-mount open" "Open as a folder, read-only")
        # archivemount writes the archive back once no tab looks into it, beside <name>.orig
        (bind (leader "ae") "plugin archive-mount 'open --edit'" "Open as a folder to edit")

        (bind (leader "m") "plugin mount" "Drives: mount, unmount, eject")
        (bind [ "g" "r" ] "plugin recent" "Recent files, via fzf")

        (bind (leader "ts") "shell --block $SHELL" "Shell in place, exit returns")
        (bind (leader "xt") "shell --orphan 'thunar .'" "Open Thunar here")
        (bind (leader "xd") (onSelection "plugin nvim-diff") "Diff 2 to 8 selected files in nvim")
        (bind (leader "xc") (onSelection "plugin chmod") "Change the mode bits")

        # sudo.yazi asks for the password each time, and Ctrl+C at the prompt cancels. Paste
        # and the links take yazi's own yank, not the system clipboard as p does; rename of
        # several files goes to nvim, and a name that ends in / creates a folder. The group
        # name says "as root", so the descriptions stay short enough for the which panel
        (bind (leader "xsp") "plugin sudo paste" "Paste")
        (bind (leader "xsP") "plugin sudo 'paste --force'" "Paste, replace")
        (bind (leader "xsr") (onSelection "plugin sudo rename") "Rename")
        (bind (leader "xsd") (onSelection "plugin sudo remove") "Trash")
        (bind (leader "xsD") (onSelection "plugin sudo 'remove --permanently'") "Delete")
        (bind (leader "xsa") "plugin sudo create" "Create")
        (bind (leader "xsl") "plugin sudo link" "Symlink")
        (bind (leader "xsL") "plugin sudo 'link --relative'" "Relative link")
        (bind (leader "xsh") "plugin sudo hardlink" "Hard link")
        (bind (leader "xsc") (onSelection "plugin sudo chmod") "Mode bits")
      ]
      ++ bookmarkBinds
      ++ sortBinds
      ++ linemodeBinds
      ++ labels;
  };
}
