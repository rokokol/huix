{ lib, pkgs, ... }:

# Bindings on top of yazi's stock keymap, which stays in force below them. Groups hang off the
# same leader as in nixvim; a chord placed first shadows a stock one that starts with the same
# key, which is how <Space>, <Tab> and `m` change their meaning here. Cyrillic twins of every
# chord, stock ones included, are added at start-up by init.lua
let
  # `leader "fg"` is <Space> f g: one character per key
  leader = keys: [ "<Space>" ] ++ lib.stringToCharacters keys;

  bind = on: run: desc: { inherit on run desc; };

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

  linemodeBinds = lib.mapAttrsToList (
    key: mode: bind (leader "u${key}") "linemode ${mode}" "Show ${mode}"
  ) linemodes;
in
{
  programs.yazi = {
    extraPackages = with pkgs; [ ripgrep-all ];

    plugins =
      lib.genAttrs
        [
          "git-column"
          "naming"
          "tab-hovered"
        ]
        (
          name:
          builtins.path {
            name = "yazi-${name}";
            path = ./plugins/${name};
            # a plugin's test runs in the flake's checks and has no business in yazi's config
            filter = path: _: baseNameOf path != "test.lua";
          }
        );

    keymap.mgr.prepend_keymap = [
      (bind "m" [ "toggle" "arrow 1" ] "Toggle selection")
      (bind "M" "toggle_all --state=on" "Select all")
      (bind "<Tab>" "tab_switch 1 --relative" "Next tab")
      (bind "<S-Tab>" "tab_switch -1 --relative" "Previous tab")
      (bind "T" "plugin tab-hovered" "Hovered directory in a new tab")
      (bind "I" "spot" "File info")
      (bind "e" "shell --block 'nvim %s'" "Open in nvim here")
      (bind "E" "shell --orphan 'kitty --detach nvim %s'" "Open in nvim in a new window")

      (bind (leader "c") "close" "Close tab")
      (bind (leader "nr") "rename --cursor=before_ext" "Rename, several at once in nvim")
      (bind (leader "nc") "plugin naming kebab" "kebab-case")
      (bind (leader "ns") "plugin naming snake" "snake_case")
      (bind (leader "nC") "plugin naming caps" "CAPS_CASE")
      (bind (leader "np") "plugin naming pascal" "PascalCase")
      (bind (leader "nm") "plugin naming camel" "camelCase")
      (bind (leader "nt") "plugin naming icao" "Transliterate Cyrillic (ICAO)")

      (bind (leader "ff") "search --via=fd" "Find names")
      (bind (leader "fg") "search --via=rg" "Find content")
      (bind (leader "fa") "search --via=rga" "Find content incl. pdf and office")
      (bind (leader "fz") "plugin zoxide" "Jump via zoxide")
      (bind (leader "fs") "plugin fzf" "Jump via fzf")
      (bind (leader "fc") "escape --search" "Cancel search")

      (bind (leader "uh") "hidden toggle" "Hidden files")
      (bind (leader "ug") "plugin git-column" "Git status column")

      (bind (leader "gg") "shell --block lazygit" "LazyGit")

      # compress.yazi asks for the archive's name and suggests one
      (bind (leader "az") "plugin compress zip" "Pack into zip")
      (bind (leader "at") "plugin compress tar.gz" "Pack into tar.gz")
      (bind (leader "a7") "plugin compress 7z" "Pack into 7z")
      (bind (leader "ap") "plugin compress '-ph 7z'" "Pack into 7z with a password")
      (bind (leader "ax") "shell 'ya pub extract --list %s'" "Extract here")

      (bind (leader "m") "plugin mount" "Drives: mount, unmount, eject")

      (bind (leader "ts") "shell --block $SHELL" "Shell in place, exit returns")
      (bind (leader "xt") "shell --orphan 'thunar .'" "Open Thunar here")
    ]
    ++ sortBinds
    ++ linemodeBinds;
  };
}
