---
title: Опции rokokol.prometheus
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.prometheus

<!-- generated: option prometheus -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.prometheus.enable` | нет | нет | да | Whether to enable Prometheus that scrapes the hosts of this flake. |
| `rokokol.prometheus.retention` | `1y` | `1y` | `1y` | How long Prometheus keeps the metrics it scraped |

Объявлено в: [`nixos/services/system/monitoring/prometheus.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/prometheus.nix)

<!-- /generated -->
