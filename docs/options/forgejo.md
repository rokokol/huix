---
title: Опции rokokol.forgejo
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.forgejo

<!-- generated: option forgejo -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `forgejo.cli` | — | — | — | The forgejo command line for this instance, to run as the forgejo user |
| `forgejo.enable` | нет | нет | да | Whether to enable the Forgejo forge. |
| `forgejo.initialPasswordFile` | `/var/lib/forgejo/initial-admin-password` | `/var/lib/forgejo/initial-admin-password` | `/var/lib/forgejo/initial-admin-password` | File with the first password of the owner's account, readable by forgejo alone |
| `forgejo.owner` | `rokokol` | `rokokol` | `rokokol` | Name of the admin account that is made on the first start |
| `forgejo.runners` | — | — | `nixos-pc` | Names of the Actions runners to register. Each takes the last 24 hex characters of its
secret from the sops secret forgejo-runner-<name>; lib/forgejo-runner-id.nix makes the rest
 |

Объявлено в: `nixos/services/tools/forgejo.nix`

<!-- /generated -->
