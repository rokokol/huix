---
title: Опции rokokol.grafana
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.grafana

<!-- generated: option grafana -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `grafana.dashboardTitles` | `Hosts`, `Guards`, `Mail`, `VPN` | `Hosts`, `Guards`, `Mail`, `VPN` | `Hosts`, `Guards`, `Mail`, `VPN`, `Hermes`, `Hindsight` | Titles of the provisioned dashboards, for what points a reader at them |
| `grafana.enable` | нет | нет | да | Whether to enable Grafana over the Prometheus of this host. |
| `grafana.resourcePolicy` | — | — | — | Resource thresholds, queries and rules for dashboards and checks |

Объявлено в: `nixos/services/system/grafana/grafana.nix`

<!-- /generated -->
