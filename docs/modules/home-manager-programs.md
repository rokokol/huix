---
title: home-manager/programs
kind: module
dir: home-manager/programs
---

# home-manager/programs

<!-- generated: module home-manager/programs -->

## [`home-manager/programs/default.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/default.nix)

## [`home-manager/programs/lsp.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/lsp.nix)

## [`home-manager/programs/molvai.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/molvai.nix)

The module defaults match the owner's setup: GigaAM-v3 Q4_K_M, Russian speech and the Russian
interface. Only the cloud model differs from a stock install, and its key comes from sops

**Units:** `molva-daemon`

## [`home-manager/programs/rofi.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/rofi.nix)

The theme and its light/dark switch come from rokokol/ddlc-rofi-theme, and its fonts
are this repository's own; only the message's face differs from its default
monospace. toggle-theme.sh calls ddlc-rofi-theme on SUPER+A
No config.rasi and no configPath override: rofi resolves a theme name in
~/.config/rofi/themes by itself, which is where the module puts both variants

## [`home-manager/programs/swayimg.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/swayimg.nix)

swayimg 5.x reads a Lua config, init.lua, and no longer the INI file of 4.x, so the
overlay scheme and the keys live here; the pin from scripts/pin-screen.sh passes its
own geometry with --position and --size, never through this file

## [`home-manager/programs/thunar.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/thunar.nix)

Folders open in yazi (programs/yazi/desktop.nix); Thunar stays at hand

## [`home-manager/programs/virtual-mic.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/virtual-mic.nix)

The camera half is a system concern (kernel module) and lives in configuration-pc.nix

## [`home-manager/programs/zen.nix`](https://github.com/rokokol/huix/blob/master/home-manager/programs/zen.nix)

<!-- /generated -->
