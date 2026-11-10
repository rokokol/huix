---
title: Опции rokokol.searxng
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.searxng

<!-- generated: option searxng -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.searxng.enable` | нет | нет | да | Whether to enable SearxNG behind nginx. |
| `rokokol.searxng.port` | `9000` | `9000` | `9000` | Loopback port of the SearXNG instance behind nginx |
| `rokokol.searxng.publicPort` | `9001` | `9001` | `9001` | Tailnet port publishing SearXNG |

Объявлено в: `nixos/services/tools/searxng.nix`

<!-- /generated -->
