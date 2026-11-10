---
title: nixos/services/ai/hindsight
kind: module
dir: nixos/services/ai/hindsight
---

# nixos/services/ai/hindsight

<!-- generated: module nixos/services/ai/hindsight -->

## [`nixos/services/ai/hindsight/backup.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hindsight/backup.nix)

**Options:** `rokokol.hindsight.backup.dumpDir`, `rokokol.hindsight.backup.mountPoint`, `rokokol.hindsight.backup.subvolumes`

More: [rokokol.hindsight options](../options/hindsight.md)

**Units:** `postgresqlBackup-hindsight`, `restic-backups-station`

## [`nixos/services/ai/hindsight/default.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hindsight/default.nix)

## [`nixos/services/ai/hindsight/monitor.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hindsight/monitor.nix)

Hindsight runs every model on a key of its own, and that key's counter is what the provider
billed — so the dashboard reads the spend instead of inferring it from tokens, which Hindsight
records for neither an embedding nor a rerank (DEVIATIONS.md, "Hindsight spends an OpenRouter
key of its own"). The same unit counts observed model calls from the trace table, including
errors, because the call counter omits the rerank scope (PITFALLS.md, "Hindsight's call
counter records chat alone"). Both reach Grafana through the textfile directory that the
station's node_exporter serves. It is not part of the Hermes monitor: Hindsight spends whether
or not the agent runs

**Units:** `hindsight-monitor`

## [`nixos/services/ai/hindsight/service.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hindsight/service.nix)

**Options:** `rokokol.hindsight.bank`, `rokokol.hindsight.client.enable`, `rokokol.hindsight.dataDir`, `rokokol.hindsight.enable`, `rokokol.hindsight.poolMax`, `rokokol.hindsight.poolMin`, `rokokol.hindsight.port`, `rokokol.hindsight.publicPort`

More: [rokokol.hindsight options](../options/hindsight.md)

**Units:** `hindsight`, `hindsight-bank-template`, `hindsight-database`, `hindsight-storage`, `postgresql`

<!-- /generated -->
