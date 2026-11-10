---
title: lib
kind: module
dir: lib
---

# lib

<!-- generated: module lib -->

## [`lib/ai-models.nix`](https://github.com/rokokol/huix/blob/master/lib/ai-models.nix)

## [`lib/drive-backup-package.nix`](https://github.com/rokokol/huix/blob/master/lib/drive-backup-package.nix)

## [`lib/forgejo-runner-id.nix`](https://github.com/rokokol/huix/blob/master/lib/forgejo-runner-id.nix)

The public part of a Forgejo runner's secret, made from the runner's name. A secret is 40 hex
characters, and Forgejo takes the first 16 as the runner's UUID, which it shows to anyone who
administers it. So those 16 come from the name, and only the last 24 are secret and live in
sops. The forge that registers a runner and the runner that connects both read this file

## [`lib/mk-host.nix`](https://github.com/rokokol/huix/blob/master/lib/mk-host.nix)

One NixOS system with Home Manager inside it; the host brings its configuration, its home
and the overlays it wants, and everything else is the same on every host

## [`lib/ru-layout.nix`](https://github.com/rokokol/huix/blob/master/lib/ru-layout.nix)

The standard Russian layout against the US character on the same physical key, for every
program that binds Latin keys and must answer to Cyrillic input. The US `/` key is left out:
in Russian it types `.`, and a pair for it would shadow the real `.` bindings

<!-- /generated -->
