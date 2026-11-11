---
title: rokokol.gpu-unlock options
kind: option
hosts: [nixos-pc]
---

# rokokol.gpu-unlock options

<!-- generated: option gpu-unlock -->

| Option | nixos-pc | Description |
| --- | --- | --- |
| `rokokol.gpu-unlock.enable` | yes | Whether to enable the GeForce tensor core unlock. |
| `rokokol.gpu-unlock.targets` | `all` | Cards to unlock, as "all" or as full PCI names that lspci -D prints. A card that is not supported is logged and skipped |

Declared in: [`nixos/pc/gpu-unlock.nix`](https://github.com/rokokol/huix/blob/master/nixos/pc/gpu-unlock.nix)

<!-- /generated -->
