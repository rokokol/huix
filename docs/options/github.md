---
title: Опции rokokol.github
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.github

<!-- generated: option github -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `mya-agent.github.api` | `https://api.github.com` | `https://api.github.com` | `https://api.github.com` | GitHub API that the proxy forwards to |
| `mya-agent.github.enable` | нет | нет | да | Whether to enable gh in the agent's session, through a proxy that holds the tokens. |
| `mya-agent.github.socket` | `/run/mya-github/api.sock` | `/run/mya-github/api.sock` | `/run/mya-github/api.sock` | Unix socket of the proxy, which only nginx and the agent's group reach |

Объявлено в: `nixos/services/ai/hermes/github.nix`

<!-- /generated -->
