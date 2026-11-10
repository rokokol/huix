---
title: Опции rokokol.client
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.client

<!-- generated: option client -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `hindsight.client.enable` | да | да | да | Whether to enable access to shared Hindsight memory. |
| `printer.client.enable` | нет | да | да | Whether to enable the print client and skill for this host's agents. |
| `printer.client.host` | `nixos-pc` | — | `nixos-pc` | SSH host of the print server, or null for the local CUPS server |
| `printer.client.prepareCommand` | — | — | `wake-pc` | Command that prepares the print host, such as a Wake-on-LAN command |

Объявлено в: `nixos/services/ai/hindsight/service.nix`, `nixos/services/devices/printer.nix`

<!-- /generated -->
