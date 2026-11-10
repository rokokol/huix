---
title: rokokol.prometheus options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.prometheus options

<!-- generated: option prometheus -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.prometheus.enable` | no | no | yes | Whether to enable Prometheus that scrapes the hosts of this flake. |
| `rokokol.prometheus.retention` | `1y` | `1y` | `1y` | How long Prometheus keeps the metrics it scraped |

Declared in: [`nixos/services/system/monitoring/prometheus.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/prometheus.nix)

<!-- /generated -->
