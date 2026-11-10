---
title: Опции rokokol.hindsight
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.hindsight

<!-- generated: option hindsight -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `hindsight.bank` | `shared` | `shared` | `shared` | Memory bank shared by pi and Hermes |
| `hindsight.dataDir` | — | — | `/srv/backup/hindsight/postgresql` | PostgreSQL subvolume on the backup volume |
| `hindsight.enable` | нет | нет | да | Whether to enable shared Hindsight memory. |
| `hindsight.poolMax` | `5` | `5` | `5` | Ceiling on the connections of the database pool |
| `hindsight.poolMin` | `1` | `1` | `1` | Connections the database pool keeps open |
| `hindsight.port` | `8888` | `8888` | `8888` | Loopback API port |
| `hindsight.publicPort` | `8788` | `8788` | `8788` | Authenticated API port on the tailnet |

Объявлено в: `nixos/services/ai/hindsight/service.nix`

<!-- /generated -->
