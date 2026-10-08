# TODO

Work planned outside this repository: pull requests to upstream projects, plugins to move into their own repositories, and forks. A patch that already lives here is described in `WORKAROUNDS.md`, and its entry is the source of truth for what it does and when it can go; this list only keeps the work from being lost

The yazi project wants every issue, pull request and commit description written by a human, with any AI help disclosed (`CONTRIBUTING.md`, section AI Policy). YaLTeR asks the same in niri. So the texts for those projects come from the owner of this repository, and the code is disclosed as AI-assisted

## Pull requests and issues

| Upstream               | Change                                                                                   | Here                                                                                                                       | State                                                                                                        |
| ---------------------- | ---------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------ |
| sxyazi/yazi            | `[langmap]` in `keymap.toml`                                                             | `patches/yazi-langmap.patch`, branch `langmap` of the yazi clone                                                           | issue [#4411](https://github.com/sxyazi/yazi/issues/4411)                                                                                                   |
| sxyazi/yazi            | group labels and `[which] fold`                                                          | `patches/yazi-which-groups.patch`, branch `which-groups`                                                                   | [#4380](https://github.com/sxyazi/yazi/pull/4380) closed unmerged; sxyazi points to a plugin in [#3774](https://github.com/sxyazi/yazi/issues/3774) |
| sxyazi/yazi            | `[which] delay`                                                                          | `patches/yazi-which-delay.patch`, branch `which-delay`, on top of `which-groups`                                           | code ready                                                                                                   |
| sxyazi/yazi            | issue: `ya.emit()` refuses the chords of `cx.which.cands`, so the example in #3617 fails | fix on branch `chordarc-data-any`, one line                                                                                | facts collected                                                                                              |
| sxyazi/yazi            | issue: `--chooser-file` and `--cwd-file` write `fd://` URLs for a search result           | nothing; the termfilechooser portal refuses such a file                                                                    | issue [#4410](https://github.com/sxyazi/yazi/issues/4410) |
| YaLTeR/wl-clipboard-rs | `wl-copy --offer MIME FILE`, several types at once                                       | the `wl-clipboard-rs` input, branch `wl-copy-multi-types` of the wl-clipboard-rs clone                                     | sent as [#88](https://github.com/YaLTeR/wl-clipboard-rs/pull/88)                                             |
| yazi-rs/plugins        | `git.yazi`: an option to show and hide its status column                                 | `plugins/git-column` and the wrapper around `Linemode.children_add` in `init.lua`, both of which go once the option exists | issue [sxyazi/yazi#4409](https://github.com/sxyazi/yazi/issues/4409) |
| folke/which-key.nvim   | keys read through `'langmap'`                                                            | the `which-key-nvim` input, branch `langmap` of the which-key.nvim clone                                                   | sent as [#1068](https://github.com/folke/which-key.nvim/pull/1068); upstream has had no commit since 2025-10 |

## Own repositories

- `rename-case.yazi`: the `naming` plugin, with case tables generated from `UnicodeData.txt` and CI; transliteration stays Cyrillic (ICAO) for now, in a layout that takes other scripts later
- `archive-mount.yazi`: the `archive-mount` plugin, an archive opened as a folder, read-only through `fuse-archive` or for editing through `archivemount`, unmounted when no tab looks into it. `fuse-archive.yazi` was tried first and rejected

## Forks

- `nix-matlab` (`gitlab:doronbehar/nix-matlab`, the `nix-matlab` input): fork it and improve the repository; what to change is still open. GitHub cannot fork a GitLab project: a copy there is an import or a mirror, and a merge request back needs a fork on GitLab
