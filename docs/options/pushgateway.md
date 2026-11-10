---
title: rokokol.pushgateway options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.pushgateway options

<!-- generated: option pushgateway -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.pushgateway.backendPort` | `9191` | `9191` | `9191` | TCP port of the Pushgateway itself, on loopback |
| `rokokol.pushgateway.causesFile` | — | — | `/run/node-push-watch/causes` | File for the silent nodes and the problems the nodes report, one cause a line, for an alert registry to read. When set, a problem no longer fails the check's unit. It lies in the unit's runtime directory, which outlives each run |
| `rokokol.pushgateway.enable` | no | no | yes | Whether to enable the Pushgateway that the restic nodes push their metrics to. |
| `rokokol.pushgateway.maxSilence` | `1h` | `1h` | `1h` | Time since the last push of a node past which the node is silent |
| `rokokol.pushgateway.port` | `9091` | `9091` | `9091` | TCP port of the tailnet-web site that the nodes push to |

Declared in: [`nixos/services/system/monitoring/pushgateway.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/pushgateway.nix)

<!-- /generated -->
