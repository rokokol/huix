---
title: Модули home-manager/programs/yazi
kind: module
---

# Модули home-manager/programs/yazi

<!-- generated: module home-manager/programs/yazi -->

## `home-manager/programs/yazi/archive-mount.nix`

The plugin lives in github:rokokol/archive-mount.yazi. Its module owns the plugin, the setup
subscription and the tools the plugin runs. The FUSE helper stays the system's: a store copy
would hide it on PATH

## `home-manager/programs/yazi/default.nix`

## `home-manager/programs/yazi/desktop.nix`

yazi's own desktop file asks for a terminal, and xdg-open cannot provide one, so this entry
opens it in a kitty window, as nixvim/opener.nix does for nvim. Folders and archives open
through it, and so does SUPER+E; it only serves as an opener, so the launcher hides it.
Thunar stays installed but is no longer the default

## `home-manager/programs/yazi/flavor.nix`

Two flavors built from the palette, so yazi looks like ddlc.nvim: each colour plays the role
it has in that theme's core groups (CursorLine, Search, FloatBorder, FloatTitle, PmenuSel).
Nothing paints the ground, so the terminal's background shows, as it does under nvim. yazi
picks the flavor from the terminal's own colour scheme and swaps it live when that changes

## `home-manager/programs/yazi/keymap.nix`

Bindings on top of yazi's stock keymap, which stays in force below them. Groups hang off the
same leader as in nixvim; a chord placed first shadows a stock one that starts with the same
key, which is how <Space>, <Tab> and `m` change their meaning here. The langmap turns a key
typed in the Russian layout into the Latin one on the same place before any of this matches

## `home-manager/programs/yazi/rename-case.nix`

The plugin lives in github:rokokol/rename-case.yazi. Its module owns the plugin alone. The
keys that run it and their names in the which popup stay in keymap.nix

## `home-manager/programs/yazi/yazi.nix`

The nixpkgs wrapper already puts the stock previewers' tools on yazi's PATH (7zz, ffmpeg,
poppler, imagemagick, chafa, resvg, fd, ripgrep, fzf, zoxide, jq, file)

<!-- /generated -->
