---
title: rokokol.forgejo-mirrors options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.forgejo-mirrors options

<!-- generated: option forgejo-mirrors -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.forgejo-mirrors.enable` | no | no | yes | Whether to enable Forgejo mirrors of the owner's GitHub repositories. |
| `rokokol.forgejo-mirrors.exclude` | — | — | `myWiki_real` | Repositories that get no mirror; a mirror made before stays |
| `rokokol.forgejo-mirrors.forks` | — | — | `obsidian-media-gallery` | Forks that get a mirror too; every repository that is not a fork gets one anyway |
| `rokokol.forgejo-mirrors.githubApi` | `https://api.github.com` | `https://api.github.com` | `https://api.github.com` | Base URL of the GitHub API |

Declared in: [`nixos/services/tools/forgejo-mirrors.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/forgejo-mirrors.nix)

<!-- /generated -->
