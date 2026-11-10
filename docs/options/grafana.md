---
title: rokokol.grafana options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.grafana options

<!-- generated: option grafana -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.grafana.dashboardTitles` | `Hosts`, `Guards`, `Mail`, `VPN` | `Hosts`, `Guards`, `Mail`, `VPN` | `Hosts`, `Guards`, `Mail`, `VPN`, `Hermes`, `Hindsight` | Titles of the provisioned dashboards, for what points a reader at them |
| `rokokol.grafana.enable` | no | no | yes | Whether to enable Grafana over the Prometheus of this host. |
| `rokokol.grafana.resourcePolicy` | — | — | — | Resource thresholds, queries and rules for dashboards and checks |

Declared in: [`nixos/services/system/grafana/grafana.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/grafana/grafana.nix)

<!-- /generated -->
