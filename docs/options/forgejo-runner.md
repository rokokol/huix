---
title: Опции rokokol.forgejo-runner
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.forgejo-runner

<!-- generated: option forgejo-runner -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `forgejo-runner.enable` | нет | да | нет | Whether to enable a Forgejo Actions runner with Docker. |
| `forgejo-runner.labels` | `docker:docker://data.forgejo.org/oci/node:22-bookworm`, `ubuntu-latest:docker://data.forgejo.org/oci/node:22-bookworm`, `nixos-pc:docker://data.forgejo.org/oci/node:22-bookworm` | `docker:docker://data.forgejo.org/oci/node:22-bookworm`, `ubuntu-latest:docker://data.forgejo.org/oci/node:22-bookworm`, `nixos-pc:docker://data.forgejo.org/oci/node:22-bookworm` | `docker:docker://data.forgejo.org/oci/node:22-bookworm`, `ubuntu-latest:docker://data.forgejo.org/oci/node:22-bookworm`, `nixos-pc:docker://data.forgejo.org/oci/node:22-bookworm` | Labels the runner takes jobs for, each mapped to the image the job runs in |
| `forgejo-runner.name` | `nixos-laptop` | `nixos-pc` | `nixos-station` | Name the forge registers the runner under, in its `rokokol.forgejo.runners` |
| `forgejo-runner.secretsFile` | `/nix/store/2z5ycydi1vlpxmm8nn2fzynsxv6b7zzg-station-secrets` | `/nix/store/2z5ycydi1vlpxmm8nn2fzynsxv6b7zzg-station-secrets` | `/nix/store/2z5ycydi1vlpxmm8nn2fzynsxv6b7zzg-station-secrets` | sops file with the secret forgejo-runner-<name>, the same file the forge reads it from,
so the secret is written once
 |
| `forgejo-runner.unit` | `forgejo-runner-nixos\x2dlaptop.service` | `forgejo-runner-nixos\x2dpc.service` | `forgejo-runner-nixos\x2dstation.service` | The runner's systemd unit, whose name the nixpkgs module escapes as a path |
| `forgejo-runner.url` | — | `http://nixos-station:3000/` | — | Root URL of the Forgejo that hands out the jobs |

Объявлено в: `nixos/services/utils/forgejo-runner.nix`

<!-- /generated -->
