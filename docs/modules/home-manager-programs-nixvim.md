---
title: Модули home-manager/programs/nixvim
kind: module
---

# Модули home-manager/programs/nixvim

<!-- generated: module home-manager/programs/nixvim -->

## `home-manager/programs/nixvim/clipboard.nix`

A yank must reach the terminal's clipboard both in a desktop session and over SSH on a host
whose desktop belongs to another machine. The host cannot answer which of the two this is:
the same configuration runs everywhere, and a workstation reached over SSH has no display for
wl-copy, so a host-role check sends a yank on the PC over SSH into nothing. The session
answers it at startup instead. A session with a Wayland socket and wl-copy keeps nvim's own
provider, so the real clipboard is both written and read. Any other session sends the yank as
OSC 52, which kitty writes to the clipboard it does own. A paste from that clipboard is the
terminal's paste key: an OSC 52 read makes kitty ask for permission, and with 'clipboard' at
unnamedplus every `p` would read it. So `p` returns the last text this nvim yanked, with its
register type

## `home-manager/programs/nixvim/default.nix`

## `home-manager/programs/nixvim/keymaps.nix`

--- Interface ---

## `home-manager/programs/nixvim/opener.nix`

nvim's own desktop file asks for a terminal, and xdg-open cannot provide one, so this entry
opens it in a kitty window. It only serves as an opener, so the launcher hides it

## `home-manager/programs/nixvim/packages.nix`

## `home-manager/programs/nixvim/settings.nix`

--- Globals ---

<!-- /generated -->
