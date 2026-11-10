---
title: rokokol.backup-heartbeat options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.backup-heartbeat options

<!-- generated: option backup-heartbeat -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.backup-heartbeat.causesFile` | — | — | `/run/backup-heartbeat/causes` | File for the problems as causes, one a line, for an alert registry to read. When set, a problem no longer fails the unit: the file carries it, and only a fault of the check itself fails it |
| `rokokol.backup-heartbeat.enable` | no | no | yes | Whether to enable the watchdog over the restic server's repositories. |
| `rokokol.backup-heartbeat.maxAge` | `36h` | `36h` | `36h` | Age of the newest snapshot past which a repository is stale |
| `rokokol.backup-heartbeat.metricsFile` | `/run/backup-heartbeat/backup.prom` | `/run/backup-heartbeat/backup.prom` | `/run/backup-heartbeat/backup.prom` | File for the newest snapshot time of each repository as Prometheus text metrics, or null for none. A tmpfiles rule makes the directory that holds it, owned by the user this check runs as, and links the file into the textfile directory of node_exporter |
| `rokokol.backup-heartbeat.minFree` | `10G` | `10G` | `10G` | Free space the backup filesystem must keep, in powers of 1024 |

Declared in: [`nixos/services/system/monitoring/backup-heartbeat.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/backup-heartbeat.nix)

<!-- /generated -->
