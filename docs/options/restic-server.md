---
title: Опции rokokol.restic-server
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.restic-server

<!-- generated: option restic-server -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.restic-server.dataDir` | — | — | `/srv/backup/restic` | Directory of the repositories, on the filesystem mounted at `mountPoint` |
| `rokokol.restic-server.enable` | нет | нет | да | Whether to enable the restic REST server, with daily snapshots of its repositories. |
| `rokokol.restic-server.localUserName` | `station` | `station` | `station` | The htpasswd account this host pushes its own state under, and so the repository's directory |
| `rokokol.restic-server.localUsers` | — | — | `station` | Users of the htpasswd that back up from this host, so no node push is expected of them |
| `rokokol.restic-server.mountPoint` | — | — | `/srv/backup` | Mountpoint of the backup filesystem; the server does not start without it |
| `rokokol.restic-server.port` | `8000` | `8000` | `8000` | TCP port of the REST server, on every interface |
| `rokokol.restic-server.preserve` | `3d 1m` | `3d 1m` | `3d 1m` | How long the snapshots of `dataDir` are kept, as btrbk's snapshot_preserve: three daily
and one monthly. It is how long a backup that a node deleted can still be restored. The
node's own `restic forget` policy is the other half and lives in the node's config
 |
| `rokokol.restic-server.snapshotDir` | — | — | `/srv/backup/snapshots/restic` | Directory of the read-only snapshots of `dataDir`, on the same filesystem |
| `rokokol.restic-server.subvolumes` | — | — | `restic`, `snapshots/restic` | Subvolumes of the backup filesystem, as paths inside `mountPoint`, for the disk layout to make |

Объявлено в: [`nixos/services/system/restic-server.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/restic-server.nix)

<!-- /generated -->
