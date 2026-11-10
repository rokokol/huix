---
title: rokokol.forgejo options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.forgejo options

<!-- generated: option forgejo -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.forgejo.backup.dumpDir` | — | — | `/srv/backup/forgejo-dump` | Directory of the nightly dump, which the station's restic backup reads. The dump holds the whole forge in one archive, so it costs its size on every snapshot, and the four that the policy keeps cost that much again |
| `rokokol.forgejo.backup.mountPoint` | — | — | `/srv/backup` | Mountpoint of the filesystem that holds the dump; the nightly dump does not run without it |
| `rokokol.forgejo.cli` | — | — | — | The forgejo command line for this instance, to run as the forgejo user |
| `rokokol.forgejo.enable` | no | no | yes | Whether to enable the Forgejo forge. |
| `rokokol.forgejo.initialPasswordFile` | `/var/lib/forgejo/initial-admin-password` | `/var/lib/forgejo/initial-admin-password` | `/var/lib/forgejo/initial-admin-password` | File with the first password of the owner's account, readable by forgejo alone |
| `rokokol.forgejo.owner` | `rokokol` | `rokokol` | `rokokol` | Name of the admin account that is made on the first start |
| `rokokol.forgejo.runners` | — | — | `nixos-pc` | Names of the Actions runners to register. Each takes the last 24 hex characters of its secret from the sops secret forgejo-runner-<name>; lib/forgejo-runner-id.nix makes the rest |

Declared in: [`nixos/services/tools/forgejo.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/forgejo.nix)

<!-- /generated -->
