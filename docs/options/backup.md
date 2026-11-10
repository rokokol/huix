---
title: Опции rokokol.backup
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.backup

<!-- generated: option backup -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `forgejo.backup.dumpDir` | — | — | `/srv/backup/forgejo-dump` | Directory of the nightly dump, which the station's restic backup reads. The dump holds
the whole forge in one archive, so it costs its size on every snapshot, and the four
that the policy keeps cost that much again
 |
| `forgejo.backup.mountPoint` | — | — | `/srv/backup` | Mountpoint of the filesystem that holds the dump; the nightly dump does not run without it |
| `hindsight.backup.dumpDir` | — | — | `/srv/backup/hindsight/dumps` | Subvolume holding consistent PostgreSQL dumps |
| `hindsight.backup.mountPoint` | — | — | `/srv/backup` | Mountpoint of the backup volume |
| `hindsight.backup.subvolumes` | — | — | `hindsight/postgresql`, `hindsight/dumps` | Subvolumes for the disk layout to create |

Объявлено в: `nixos/services/ai/hindsight/backup.nix`, `nixos/services/tools/forgejo.nix`

<!-- /generated -->
