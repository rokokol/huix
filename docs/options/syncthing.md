---
title: rokokol.syncthing options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.syncthing options

<!-- generated: option syncthing -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.syncthing.archive.dir` | — | — | `/srv/backup/syncthing` | Directory of the folders, on the filesystem mounted at `mountPoint` |
| `rokokol.syncthing.archive.editor` | — | — | `mya` | A user who edits the folders on this host. Syncthing runs as that user, so the files are theirs, and sends their changes to the peers. With null, Syncthing runs as its own user and only receives |
| `rokokol.syncthing.archive.enable` | no | no | yes | Whether to enable a receive-only copy of every folder, with the old versions of its files. |
| `rokokol.syncthing.archive.folders` | — | — | `/home/rokokol/.local/share/pi-shared=/srv/backup/syncthing/pi-shared`, `/home/rokokol/.pi/agent=/srv/backup/syncthing/pi-nixos-laptop`, `/home/rokokol/myWiki=/srv/backup/syncthing/myWiki` | Where the workstations keep each folder, and where this host keeps it |
| `rokokol.syncthing.archive.mountPoint` | — | — | `/srv/backup` | Mountpoint of the archive's filesystem; Syncthing does not start without it |
| `rokokol.syncthing.archive.snapshotDir` | — | — | `/srv/backup/snapshots/syncthing` | Directory of the read-only snapshots of every folder, on the same filesystem |
| `rokokol.syncthing.archive.subvolumes` | — | — | `syncthing/myWiki`, `syncthing/pi-nixos-laptop`, `syncthing/pi-nixos-pc`, `syncthing/pi-shared`, `snapshots/syncthing` | Subvolumes of the archive, as paths inside `mountPoint`, for the disk layout to make |
| `rokokol.syncthing.deviceId` | `IACQG6Z-QHUKT7Y-EZXPKTH-BIT3LJR-BCXTRV6-FZZK3LB-SUKSHBR-UG44GAM` | `MNSJ7QK-4YOWUOS-3O5MSOT-UXON7VW-PZFY2YC-34MDG2H-UHTWJ7H-QLTDKQV` | `6CQJLFE-TE77FII-NTQQIOX-XKDOALI-WFDZU4D-SJLMJ62-MUMN5S4-KSPMJQV` | This host's device ID, as its Syncthing shows it; the other hosts trust it |
| `rokokol.syncthing.enable` | yes | yes | yes | Whether to enable Syncthing between the workstations, the phone and the archive. |
| `rokokol.syncthing.keyFromSops` | yes | yes | yes | Whether to enable the device's key and certificate from the sops secrets syncthing-key-<host> and syncthing-cert-<host>, in the host's default sops file . |

Declared in: [`nixos/services/tools/syncthing.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/syncthing.nix)

<!-- /generated -->
