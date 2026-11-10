---
title: Опции rokokol.hindsight
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.hindsight

<!-- generated: option hindsight -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.hindsight.backup.dumpDir` | — | — | `/srv/backup/hindsight/dumps` | Subvolume holding consistent PostgreSQL dumps |
| `rokokol.hindsight.backup.mountPoint` | — | — | `/srv/backup` | Mountpoint of the backup volume |
| `rokokol.hindsight.backup.subvolumes` | — | — | `hindsight/postgresql`, `hindsight/dumps` | Subvolumes for the disk layout to create |
| `rokokol.hindsight.bank` | `shared` | `shared` | `shared` | Memory bank shared by pi and Hermes |
| `rokokol.hindsight.client.enable` | да | да | да | Whether to enable access to shared Hindsight memory. |
| `rokokol.hindsight.dataDir` | — | — | `/srv/backup/hindsight/postgresql` | PostgreSQL subvolume on the backup volume |
| `rokokol.hindsight.enable` | нет | нет | да | Whether to enable shared Hindsight memory. |
| `rokokol.hindsight.poolMax` | `5` | `5` | `5` | Ceiling on the connections of the database pool |
| `rokokol.hindsight.poolMin` | `1` | `1` | `1` | Connections the database pool keeps open |
| `rokokol.hindsight.port` | `8888` | `8888` | `8888` | Loopback API port |
| `rokokol.hindsight.publicPort` | `8788` | `8788` | `8788` | Authenticated API port on the tailnet |

Объявлено в: [`nixos/services/ai/hindsight/backup.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hindsight/backup.nix), [`nixos/services/ai/hindsight/service.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hindsight/service.nix)

<!-- /generated -->
