---
title: rokokol.searxng options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.searxng options

<!-- generated: option searxng -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.searxng.enable` | no | no | yes | Whether to enable SearxNG behind nginx. |
| `rokokol.searxng.port` | `9000` | `9000` | `9000` | Loopback port of the SearXNG instance behind nginx |
| `rokokol.searxng.publicPort` | `9001` | `9001` | `9001` | Tailnet port publishing SearXNG |

Declared in: [`nixos/services/tools/searxng.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/searxng.nix)

<!-- /generated -->
