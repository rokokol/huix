---
title: Опции rokokol.archive
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.archive

<!-- generated: option archive -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `syncthing.archive.dir` | — | — | `/srv/backup/syncthing` | Directory of the folders, on the filesystem mounted at `mountPoint` |
| `syncthing.archive.editor` | — | — | `mya` | A user who edits the folders on this host. Syncthing runs as that user, so the files
are theirs, and sends their changes to the peers. With null, Syncthing runs as its
own user and only receives
 |
| `syncthing.archive.enable` | нет | нет | да | Whether to enable a receive-only copy of every folder, with the old versions of its files. |
| `syncthing.archive.folders` | — | — | `/home/rokokol/.local/share/pi-shared=/srv/backup/syncthing/pi-shared`, `/home/rokokol/.pi/agent=/srv/backup/syncthing/pi-nixos-laptop`, `/home/rokokol/myWiki=/srv/backup/syncthing/myWiki` | Where the workstations keep each folder, and where this host keeps it |
| `syncthing.archive.mountPoint` | — | — | `/srv/backup` | Mountpoint of the archive's filesystem; Syncthing does not start without it |
| `syncthing.archive.snapshotDir` | — | — | `/srv/backup/snapshots/syncthing` | Directory of the read-only snapshots of every folder, on the same filesystem |
| `syncthing.archive.subvolumes` | — | — | `syncthing/myWiki`, `syncthing/pi-nixos-laptop`, `syncthing/pi-nixos-pc`, `syncthing/pi-shared`, `snapshots/syncthing` | Subvolumes of the archive, as paths inside `mountPoint`, for the disk layout to make |

Объявлено в: `nixos/services/tools/syncthing.nix`

<!-- /generated -->
