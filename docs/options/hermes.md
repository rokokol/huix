---
title: Опции rokokol.hermes
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.hermes

<!-- generated: option hermes -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `mya-agent.hermes.backup.dataDir` | — | — | `/srv/backup/hermes` | Subvolume that holds the mutable Hermes home |
| `mya-agent.hermes.backup.enable` | нет | нет | да | Whether to enable Hermes state snapshots and a local restic backup. |
| `mya-agent.hermes.backup.mountPoint` | — | — | `/srv/backup` | Mountpoint of the backup volume |
| `mya-agent.hermes.backup.subvolumes` | — | — | `hermes` | Subvolumes for the disk layout to create |
| `mya-agent.hermes.cronTopic` | — | — | `1089660` | Topic of the owner's chat that takes cron jobs aimed at the home channel, and the spend of cron sessions |
| `mya-agent.hermes.dashboardAutoStart` | нет | нет | да | Start the dashboard at boot after its memory use has been measured |
| `mya-agent.hermes.dashboardPort` | `9120` | `9120` | `9120` | Tailnet port of the Hermes web dashboard |
| `mya-agent.hermes.homeTopic` | — | — | `1089068` | Topic of the owner's chat that is Hermes' home channel, for gateway notices |
| `mya-agent.hermes.memoryMax` | `1200M` | `1200M` | `3G` | Memory limit of each Hermes service |
| `mya-agent.hermes.monitor.api` | `https://openrouter.ai/api/v1` | `https://openrouter.ai/api/v1` | `https://openrouter.ai/api/v1` | OpenRouter API endpoint |
| `mya-agent.hermes.monitor.enable` | нет | нет | да | Whether to enable Hermes metrics and balance notifications. |
| `mya-agent.hermes.monitor.lowBalance` | `5.00` | `5.00` | `5.00` | Account balance in USD below which a notification is sent |
| `mya-agent.hermes.reportsTopic` | — | — | `1089071` | Topic of the owner's chat that takes station alerts, balance notices and the spend of sessions that run outside the chat; a chat session hears of its spend where it runs |
| `mya-agent.hermes.webhookPort` | `8644` | `8644` | `8644` | Loopback port of the signed alert webhook |

Объявлено в: `nixos/services/ai/hermes/backup.nix`, `nixos/services/ai/hermes/hermes.nix`, `nixos/services/ai/hermes/monitor.nix`

<!-- /generated -->
