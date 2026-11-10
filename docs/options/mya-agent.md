---
title: Опции rokokol.mya-agent
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.mya-agent

<!-- generated: option mya-agent -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `mya-agent.directories` |  |  | `myWiki=/srv/backup/syncthing/myWiki` | Directories outside the home that the session edits, by the path of their link inside
the home. Each is open in the sandbox
 |
| `mya-agent.enable` | нет | нет | да | Whether to enable the station agent reachable through Telegram. |
| `mya-agent.extraGroups` | `cdrom` | `cdrom` | `wake-pc`, `systemd-journal` | Groups of the session's user, for what its `packages` read |
| `mya-agent.hiddenPaths` | — | — | `/srv/backup`, `/var/lib/syncthing` | Paths the session sees empty, each under a read-only tmpfs. A directory in
`directories` stays open even under one of them
 |
| `mya-agent.home` | `/home/mya` | `/home/mya` | `/home/mya` | The home of the session's user |
| `mya-agent.notify` | — | — | `/nix/store/wbcv1c7arpqfs2926sw8j82l5pwvsllj-mya-agent-notify/bin/mya-agent-notify` | Command that delivers an alert to the agent webhook |
| `mya-agent.packages` | — | — | — | Commands the session can run beside the system's, in its user's profile |
| `mya-agent.pythonPackages` | — | — | — | Python libraries that the session's `python3` can import, chosen from its package set |
| `mya-agent.repositories` |  |  | `huix=https://github.com/rokokol/huix` | Repositories the session works in, by their path under its home. Each is cloned when it
is missing, and pulled only by `syncUnit` or by the session itself. Its group reads it,
so the owner can fetch from it
 |
| `mya-agent.syncUnit` | — | — | `mya-agent-sync.service` | The unit that commits whatever the session left in its `repositories` under the name
of its user, then rebases each on its upstream. scripts/agent-sync.sh says how
 |
| `mya-agent.syncedBy` | — | — | `rokokol` | The user who may start `syncUnit`, as sync.sh does over SSH |
| `mya-agent.user` | `mya` | `mya` | `mya` | The user of the session |

Объявлено в: `nixos/services/ai/hermes/agent.nix`, `nixos/services/ai/hermes/hermes.nix`

<!-- /generated -->
