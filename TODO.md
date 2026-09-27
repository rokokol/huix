# TODO

Work planned outside this repository: pull requests to upstream projects, plugins to move into their own repositories, and forks. A patch that already lives here is described in `WORKAROUNDS.md`, and its entry is the source of truth for what it does and when it can go; this list only keeps the work from being lost

The yazi project wants every issue, pull request and commit description written by a human, with any AI help disclosed (`CONTRIBUTING.md`, section AI Policy). YaLTeR asks the same in niri. So the texts for those projects come from the owner of this repository, and the code is disclosed as AI-assisted

## Pull requests and issues

| Upstream | Change | Here | State |
|---|---|---|---|
| sxyazi/yazi | `[langmap]` in `keymap.toml` | `patches/yazi-langmap.patch`, branch `langmap` of the yazi clone | code ready |
| sxyazi/yazi | group labels and `[which] fold` | `patches/yazi-which-groups.patch`, branch `which-groups` | code and tests ready; screenshots in `~/Pictures/yazi-pr` |
| sxyazi/yazi | `[which] delay` | `patches/yazi-which-delay.patch`, branch `which-delay`, on top of `which-groups` | code ready |
| sxyazi/yazi | issue: `ya.emit()` refuses the chords of `cx.which.cands`, so the example in #3617 fails | fix on branch `chordarc-data-any`, one line | facts collected |
| YaLTeR/wl-clipboard-rs | `wl-copy --offer MIME FILE`, several types at once | `patches/wl-copy-offer.patch`, branch `wl-copy-multi-types` of the wl-clipboard-rs clone | waits for a check that files copied in yazi paste into Thunar |
| folke/which-key.nvim | keys read through `'langmap'` | `patches/which-key-langmap.patch` | optional: no commit upstream since 2025-10 |

## Own repositories

- `rename-case.yazi`: the `naming` plugin, with case tables generated from `UnicodeData.txt`, CI, and transliteration for several scripts
- the `info` plugin, under a name still to choose; before that, its own Base and Image sections instead of the `spot_base` helpers of yazi's built-in plugins

## Forks

- `nix-matlab` (`gitlab:doronbehar/nix-matlab`, the `nix-matlab` input): fork it and improve the repository; what to change is still open. GitHub cannot fork a GitLab project: a copy there is an import or a mirror, and a merge request back needs a fork on GitLab
