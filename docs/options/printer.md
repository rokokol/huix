---
title: Опции rokokol.printer
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.printer

<!-- generated: option printer -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.printer.client.enable` | нет | да | да | Whether to enable the print client and skill for this host's agents. |
| `rokokol.printer.client.host` | `nixos-pc` | — | `nixos-pc` | SSH host of the print server, or null for the local CUPS server |
| `rokokol.printer.client.prepareCommand` | — | — | `wake-pc` | Command that prepares the print host, such as a Wake-on-LAN command |
| `rokokol.printer.enable` | нет | да | нет | Whether to enable printing (CUPS + gutenprint + Epson L120 driver). |
| `rokokol.printer.skill` | `/nix/store/az178f0r8gyc37y2ym93k5ck06288zcx-print-skill` | `/nix/store/az178f0r8gyc37y2ym93k5ck06288zcx-print-skill` | `/nix/store/az178f0r8gyc37y2ym93k5ck06288zcx-print-skill` | Skill for local or remote printing |

Объявлено в: `nixos/services/devices/printer.nix`

<!-- /generated -->
