---
title: Модули nixos/services/devices
kind: module
---

# Модули nixos/services/devices

<!-- generated: module nixos/services/devices -->

## `nixos/services/devices/printer.nix`

**Опции:** `rokokol.printer.client.enable`, `rokokol.printer.client.host`, `rokokol.printer.client.prepareCommand`, `rokokol.printer.enable`, `rokokol.printer.skill`

Подробнее: [опции rokokol.printer](../options/printer.md)

## `nixos/services/devices/sensors.nix`

**Опции:** `rokokol.sensors.enable`

Подробнее: [опции rokokol.sensors](../options/sensors.md)

## `nixos/services/devices/tablet.nix`

Hide ANY physical graphics tablet from libinput/Hyprland: only the
OpenTabletDriver virtual device drives the cursor. Otherwise it glitches

**Опции:** `rokokol.tablet.enable`

Подробнее: [опции rokokol.tablet](../options/tablet.md)

## `nixos/services/devices/vial.nix`

The uaccess tag gives an ACL only when it is set before 73-seat-late.rules runs. extraRules
goes to 99-local.rules, which is too late, so the rule is a package with a lower number

**Опции:** `rokokol.vial.enable`

Подробнее: [опции rokokol.vial](../options/vial.md)

<!-- /generated -->
