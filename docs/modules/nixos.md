---
title: nixos
kind: module
dir: nixos
---

# nixos

<!-- generated: module nixos -->

## [`nixos/boot.nix`](https://github.com/rokokol/huix/blob/master/nixos/boot.nix)

## [`nixos/btrfs.nix`](https://github.com/rokokol/huix/blob/master/nixos/btrfs.nix)

hardware-configuration.nix regenerates, so btrfs options cannot live there. btrfs takes
compress for the whole volume from the subvolume that mounts first, hence every point

**Options:** `rokokol.btrfs.mounts`, `rokokol.snapshots.enable`

More: [rokokol.btrfs options](../options/btrfs.md), [rokokol.snapshots options](../options/snapshots.md)

## [`nixos/configuration-laptop.nix`](https://github.com/rokokol/huix/blob/master/nixos/configuration-laptop.nix)

Linux 6.18.58 and newer never report a lid switch change on this machine, so the lid stops
suspending and the lid-mode binds go silent (see WORKAROUNDS.md)

## [`nixos/configuration-pc.nix`](https://github.com/rokokol/huix/blob/master/nixos/configuration-pc.nix)

Linux 6.18.58 and newer never report a power button press on this machine, so the power key
reaches neither logind nor Hyprland (see WORKAROUNDS.md)

## [`nixos/configuration-station.nix`](https://github.com/rokokol/huix/blob/master/nixos/configuration-station.nix)

## [`nixos/default.nix`](https://github.com/rokokol/huix/blob/master/nixos/default.nix)

## [`nixos/sound.nix`](https://github.com/rokokol/huix/blob/master/nixos/sound.nix)

**Options:** `rokokol.sound.enable`

More: [rokokol.sound options](../options/sound.md)

## [`nixos/system.nix`](https://github.com/rokokol/huix/blob/master/nixos/system.nix)

Shared system baseline for every host. The truly host-specific bits
(hostName, user description) live in nixos/<host>/system.nix; membership
in groups owned by modules (docker, nvidia, …) stays in those modules
themselves

<!-- /generated -->
