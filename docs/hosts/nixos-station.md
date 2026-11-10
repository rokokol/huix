---
title: Host nixos-station
kind: host
hosts: [nixos-station]
---

# Host nixos-station

<!-- generated: host nixos-station -->

System: `x86_64-linux`

Configured in [`nixos/configuration-station.nix`](https://github.com/rokokol/huix/blob/master/nixos/configuration-station.nix)

**Services declared in this repository:** `alert-digest`, `alert-reconcile`, `backup-heartbeat`, `btrbk-restic`, `btrbk-syncthing`, `forgejo`, `forgejo-dump`, `forgejo-dump-dir`, `forgejo-mirrors`, `forgejo-owner`, `forgejo-runners`, `grafana-alerts`, `hermes-agent`, `hermes-backend`, `hermes-backup-zip`, `hermes-hindsight-settings`, `hermes-monitor`, `hermes-state`, `hindsight`, `hindsight-bank-template`, `hindsight-database`, `hindsight-monitor`, `hindsight-storage`, `mya-agent-clone`, `node-push-watch`, `postgresql`, `postgresqlBackup-hindsight`, `radicale`, `restic-backups-station`, `restic-cloud`, `restic-cloud-heartbeat`, `smartd`, `syncthing`, `syncthing-init`, `zram-metrics`

**Timers:** `alert-digest`, `alert-reconcile`, `backup-heartbeat`, `btrbk-restic`, `btrbk-syncthing`, `forgejo-dump`, `forgejo-mirrors`, `hermes-monitor`, `hindsight-monitor`, `node-push-watch`, `postgresqlBackup-hindsight`, `restic-backups-station`, `restic-cloud`, `restic-cloud-heartbeat`, `zram-metrics`

Web services on the private network

| Service | Port | On the home network |
| --- | --- | --- |
| `forgejo` | `3000` | yes |
| `grafana` | `3200` | yes |
| `hermes` | `9120` | no |
| `hindsight` | `8788` | no |
| `pushgateway` | `9091` | no |
| `radicale` | `5232` | no |
| `searxng` | `9001` | no |

**The firewall opens:** TCP —, UDP `41641`

**Sops secrets, by name:** `alert-mail-aliases`, `alert-mail-msmtprc`, `drive-backup-client`, `forgejo-runner-nixos-pc`, `github-mirror-token`, `github-token`, `github-token-classic`, `grafana-admin-password`, `grafana-secret-key`, `hermes-dashboard-password`, `hermes-dashboard-secret`, `hermes-webhook-secret`, `hindsight-api-token`, `hindsight-client-token`, `mail-agent`, `opencode-go-mya-key`, `openrouter-api-key`, `openrouter-hindsight-api-key`, `pc-mac`, `pushgateway-htpasswd`, `radicale-password-mya`, `radicale-password-rokokol`, `restic-server-htpasswd`, `rokokol-password-hash`, `searxng-secret-key`, `station-restic-password`, `station-restic-rest-password`, `syncthing-cert-nixos-station`, `syncthing-key-nixos-station`, `telegram-api-hash`, `telegram-api-id`, `telegram-bot-token`, `telegram-owner-chat-id`

Session variables

| Variable | Value |
| --- | --- |
| `CONTRIB_HOME` | `/home/mya/.local/state/agent-skills/contributing` |
| `LOCALE_ARCHIVE_2_27` | `/nix/store/00s4gff16566pz4z1ydragxa1dra03cz-glibc-locales-2.44-57/lib/locale/locale-archive` |
| `PRINT_HOST` | `nixos-pc` |
| `PRINT_PREPARE_COMMAND` | `wake-pc` |

<!-- /generated -->
