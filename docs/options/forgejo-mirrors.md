---
title: Опции rokokol.forgejo-mirrors
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.forgejo-mirrors

<!-- generated: option forgejo-mirrors -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.forgejo-mirrors.enable` | нет | нет | да | Whether to enable Forgejo mirrors of the owner's GitHub repositories. |
| `rokokol.forgejo-mirrors.exclude` | — | — | `myWiki_real` | Repositories that get no mirror; a mirror made before stays |
| `rokokol.forgejo-mirrors.forks` | — | — | `obsidian-media-gallery` | Forks that get a mirror too; every repository that is not a fork gets one anyway |
| `rokokol.forgejo-mirrors.githubApi` | `https://api.github.com` | `https://api.github.com` | `https://api.github.com` | Base URL of the GitHub API |

Объявлено в: `nixos/services/tools/forgejo-mirrors.nix`

<!-- /generated -->
