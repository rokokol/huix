---
title: Модули nixos
kind: module
---

# Модули nixos

<!-- generated: module nixos -->

## `nixos/boot.nix`

## `nixos/btrfs.nix`

hardware-configuration.nix regenerates, so btrfs options cannot live there. btrfs takes
compress for the whole volume from the subvolume that mounts first, hence every point

**Опции:** `rokokol.btrfs.mounts`, `rokokol.snapshots.enable`

Подробнее: [опции rokokol.btrfs](../options/btrfs.md), [опции rokokol.snapshots](../options/snapshots.md)

## `nixos/configuration-laptop.nix`

Linux 6.18.58 and newer never report a lid switch change on this machine, so the lid stops
suspending and the lid-mode binds go silent (see WORKAROUNDS.md)

## `nixos/configuration-pc.nix`

Linux 6.18.58 and newer never report a power button press on this machine, so the power key
reaches neither logind nor Hyprland (see WORKAROUNDS.md)

## `nixos/configuration-station.nix`

## `nixos/default.nix`

## `nixos/sound.nix`

**Опции:** `rokokol.sound.enable`

Подробнее: [опции rokokol.sound](../options/sound.md)

## `nixos/system.nix`

Shared system baseline for every host. The truly host-specific bits
(hostName, user description) live in nixos/<host>/system.nix; membership
in groups owned by modules (docker, nvidia, …) stays in those modules
themselves

<!-- /generated -->
