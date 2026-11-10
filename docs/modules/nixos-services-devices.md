---
title: nixos/services/devices
kind: module
dir: nixos/services/devices
---

# nixos/services/devices

<!-- generated: module nixos/services/devices -->

## [`nixos/services/devices/printer.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/devices/printer.nix)

**Options:** `rokokol.printer.client.enable`, `rokokol.printer.client.host`, `rokokol.printer.client.prepareCommand`, `rokokol.printer.enable`, `rokokol.printer.skill`

More: [rokokol.printer options](../options/printer.md)

## [`nixos/services/devices/sensors.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/devices/sensors.nix)

**Options:** `rokokol.sensors.enable`

More: [rokokol.sensors options](../options/sensors.md)

## [`nixos/services/devices/tablet.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/devices/tablet.nix)

Hide ANY physical graphics tablet from libinput/Hyprland: only the
OpenTabletDriver virtual device drives the cursor. Otherwise it glitches

**Options:** `rokokol.tablet.enable`

More: [rokokol.tablet options](../options/tablet.md)

## [`nixos/services/devices/vial.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/devices/vial.nix)

The uaccess tag gives an ACL only when it is set before 73-seat-late.rules runs. extraRules
goes to 99-local.rules, which is too late, so the rule is a package with a lower number

**Options:** `rokokol.vial.enable`

More: [rokokol.vial options](../options/vial.md)

<!-- /generated -->
