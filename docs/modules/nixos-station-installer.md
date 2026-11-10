---
title: nixos/station/installer
kind: module
dir: nixos/station/installer
---

# nixos/station/installer

<!-- generated: module nixos/station/installer -->

## [`nixos/station/installer/iso.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/installer/iso.nix)

A console-only installer image whose store already holds the system it installs and the disko
program for its disk, so the install needs no network and no store in RAM. It holds no secret:
make-station-iso.sh adds them to a copy, and install-station.sh, run by the unit below, does
the rest. Every fact about the installed system comes from the target's own configuration

**Юниты:** `station-install`

## [`nixos/station/installer/make-iso.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/installer/make-iso.nix)

scripts/make-station-iso.sh with xorriso and the tools it calls on its PATH, so the flake's
lock pins them and the shell it runs from needs none of them. The flake runs it as an app and
the install test runs it to add its fixture secrets, so both go through the same command. The
script and its lib are the only files copied, so an edit to another script moves nothing here

## [`nixos/station/installer/mk-image.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/installer/mk-image.nix)

The installer image as a NixOS system, for the one system it installs. The flake builds it for
nixos-station and the install test for a variant with fixture secrets, so both run the same
image; `modules` adds what only the test needs

<!-- /generated -->
