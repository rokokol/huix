---
title: rokokol.mya-agent options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.mya-agent options

<!-- generated: option mya-agent -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.mya-agent.directories` |  |  | `myWiki=/srv/backup/syncthing/myWiki` | Directories outside the home that the session edits, by the path of their link inside the home. Each is open in the sandbox |
| `rokokol.mya-agent.enable` | no | no | yes | Whether to enable the station agent reachable through Telegram. |
| `rokokol.mya-agent.extraGroups` | `cdrom` | `cdrom` | `wake-pc`, `systemd-journal` | Groups of the session's user, for what its `packages` read |
| `rokokol.mya-agent.git.email` | — | — | `mya@rokokol.art` | The address on every commit of the session and of `syncUnit` |
| `rokokol.mya-agent.git.name` | `mya` | `mya` | `mya` | The name on every commit of the session and of `syncUnit` |
| `rokokol.mya-agent.github.api` | `https://api.github.com` | `https://api.github.com` | `https://api.github.com` | GitHub API that the proxy forwards to |
| `rokokol.mya-agent.github.enable` | no | no | yes | Whether to enable gh in the agent's session, through a proxy that holds the tokens. |
| `rokokol.mya-agent.github.socket` | `/run/mya-github/api.sock` | `/run/mya-github/api.sock` | `/run/mya-github/api.sock` | Unix socket of the proxy, which only nginx and the agent's group reach |
| `rokokol.mya-agent.guest.enable` | yes | yes | no | Whether to enable the session's user without the session, for the agent on another host to log in to over SSH. It reaches no service on this host's loopback but the resolver and `loopbackPorts`, since such a service trusts every local user, and of the owner's files only `shares` . |
| `rokokol.mya-agent.guest.loopbackPorts` |  |  |  | TCP ports on this host's loopback that the session's user still reaches, by the name of what listens there |
| `rokokol.mya-agent.guest.owner` | `rokokol` | `rokokol` | — | The user whose directories `shares` show to the session's user |
| `rokokol.mya-agent.guest.power.enable` | yes | yes | no | Whether to enable the units that let the guest put this host to sleep, lock it and turn it off. |
| `rokokol.mya-agent.guest.shares` | `Documents=path=/home/rokokol/Documents`, `writable=yes`, `Downloads=path=/home/rokokol/Downloads`, `writable=yes`, `Pocket=path=/home/rokokol/Pocket`, `writable=yes`, `Projects=path=/home/rokokol/Projects`, `writable=no` | `Documents=path=/home/rokokol/Documents`, `writable=yes`, `Downloads=path=/home/rokokol/Downloads`, `writable=yes`, `Pocket=path=/home/rokokol/Pocket`, `writable=yes`, `Projects=path=/home/rokokol/Projects`, `writable=no` |  | The owner's directories the session's user sees, by the path under its home. A share it only reads shows what any other user may read there, so a file only the owner may read stays closed. In a writable share every file looks like the session user's own, and a file it makes is the owner's on disk. The rest of the owner's home stays out of reach |
| `rokokol.mya-agent.hermes.backup.dataDir` | — | — | `/srv/backup/hermes` | Subvolume that holds the mutable Hermes home |
| `rokokol.mya-agent.hermes.backup.enable` | no | no | yes | Whether to enable Hermes state snapshots and a local restic backup. |
| `rokokol.mya-agent.hermes.backup.mountPoint` | — | — | `/srv/backup` | Mountpoint of the backup volume |
| `rokokol.mya-agent.hermes.backup.subvolumes` | — | — | `hermes` | Subvolumes for the disk layout to create |
| `rokokol.mya-agent.hermes.cronTopic` | — | — | `1089660` | Topic of the owner's chat that takes cron jobs aimed at the home channel, and the spend of cron sessions |
| `rokokol.mya-agent.hermes.dashboardAutoStart` | no | no | yes | Start the dashboard at boot after its memory use has been measured |
| `rokokol.mya-agent.hermes.dashboardPort` | `9120` | `9120` | `9120` | Tailnet port of the Hermes web dashboard |
| `rokokol.mya-agent.hermes.homeTopic` | — | — | `1089068` | Topic of the owner's chat that is Hermes' home channel, for gateway notices |
| `rokokol.mya-agent.hermes.memoryMax` | `1200M` | `1200M` | `3G` | Memory limit of each Hermes service |
| `rokokol.mya-agent.hermes.monitor.api` | `https://openrouter.ai/api/v1` | `https://openrouter.ai/api/v1` | `https://openrouter.ai/api/v1` | OpenRouter API endpoint |
| `rokokol.mya-agent.hermes.monitor.enable` | no | no | yes | Whether to enable Hermes metrics and balance notifications. |
| `rokokol.mya-agent.hermes.monitor.lowBalance` | `5.00` | `5.00` | `5.00` | Account balance in USD below which a notification is sent |
| `rokokol.mya-agent.hermes.reportsTopic` | — | — | `1089071` | Topic of the owner's chat that takes station alerts, balance notices and the spend of sessions that run outside the chat; a chat session hears of its spend where it runs |
| `rokokol.mya-agent.hermes.webhookPort` | `8644` | `8644` | `8644` | Loopback port of the signed alert webhook |
| `rokokol.mya-agent.hiddenPaths` | — | — | `/srv/backup`, `/var/lib/syncthing` | Paths the session sees empty, each under a read-only tmpfs. A directory in `directories` stays open even under one of them |
| `rokokol.mya-agent.home` | `/home/mya` | `/home/mya` | `/home/mya` | The home of the session's user |
| `rokokol.mya-agent.notify` | — | — | `/nix/store/wbcv1c7arpqfs2926sw8j82l5pwvsllj-mya-agent-notify/bin/mya-agent-notify` | Command that delivers an alert to the agent webhook |
| `rokokol.mya-agent.packages` | — | — | — | Commands the session can run beside the system's, in its user's profile |
| `rokokol.mya-agent.power.enable` | no | no | yes | Whether to enable the skill that wakes, puts to sleep, locks and turns off the workstations. |
| `rokokol.mya-agent.pythonPackages` | — | — | — | Python libraries that the session's `python3` can import, chosen from its package set |
| `rokokol.mya-agent.repositories` |  |  | `huix=https://github.com/rokokol/huix` | Repositories the session works in, by their path under its home. Each is cloned when it is missing, and pulled only by `syncUnit` or by the session itself. Its group reads it, so the owner can fetch from it |
| `rokokol.mya-agent.syncUnit` | — | — | `mya-agent-sync.service` | The unit that commits whatever the session left in its `repositories` under the name of its user, then rebases each on its upstream. scripts/agent-sync.sh says how |
| `rokokol.mya-agent.syncedBy` | — | — | `rokokol` | The user who may start `syncUnit`, as sync.sh does over SSH |
| `rokokol.mya-agent.user` | `mya` | `mya` | `mya` | The user of the session |

Declared in: [`nixos/services/ai/hermes/agent.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/agent.nix), [`nixos/services/ai/hermes/backup.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/backup.nix), [`nixos/services/ai/hermes/github.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/github.nix), [`nixos/services/ai/hermes/hermes.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/hermes.nix), [`nixos/services/ai/hermes/monitor.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/monitor.nix), [`nixos/services/ai/hermes/power.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/power.nix)

<!-- /generated -->
