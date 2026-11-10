---
title: nixos/desktop
kind: module
dir: nixos/desktop
---

# nixos/desktop

<!-- generated: module nixos/desktop -->

## [`nixos/desktop/agent-guest.nix`](https://github.com/rokokol/huix/blob/master/nixos/desktop/agent-guest.nix)

The station's agent logs in to a workstation over SSH, as a guest user of its own. It sees these
of the owner's directories, and the rest of the owner's home stays out of its reach

## [`nixos/desktop/core-options.nix`](https://github.com/rokokol/huix/blob/master/nixos/desktop/core-options.nix)

The umbrella of every desktop and workstation module: each of them defaults its own
rokokol.<name>.enable to this one, so a host turns the whole desktop on with a single line
and still can turn one piece off. The modules of nixos/desktop have no use apart from the
desktop, so they read the umbrella itself and declare no flag of their own

**Options:** `rokokol.workstation.enable`

More: [rokokol.workstation options](../options/workstation.md)

## [`nixos/desktop/default.nix`](https://github.com/rokokol/huix/blob/master/nixos/desktop/default.nix)

## [`nixos/desktop/logind.nix`](https://github.com/rokokol/huix/blob/master/nixos/desktop/logind.nix)

Power key → Hyprland (XF86PowerOff → rofi-power.sh); without ignore logind would poweroff
immediately

## [`nixos/desktop/portals.nix`](https://github.com/rokokol/huix/blob/master/nixos/desktop/portals.nix)

<!-- /generated -->
