---
title: Модули nixos/services/system/grafana/dashboards
kind: module
---

# Модули nixos/services/system/grafana/dashboards

<!-- generated: module nixos/services/system/grafana/dashboards -->

## `nixos/services/system/grafana/dashboards/guards.nix`

The dashboard of the watchers: what is open and which watched unit failed, how fresh the
backups and the pushes of the nodes are, the disks by SMART, zram, btrfs with its scrubs and
snapshots, and Syncthing. The thresholds are the ones the watchers alert at, in seconds and
bytes, so a value turns red where its alert fires

## `nixos/services/system/grafana/dashboards/hermes.nix`

## `nixos/services/system/grafana/dashboards/hindsight.nix`

## `nixos/services/system/grafana/dashboards/hosts.nix`

The dashboard of the hosts: a row of each host with its CPU, memory, swap traffic, CPU
temperature and disks, and a row of each host that has a GPU. The temperature turns to danger
where waybar does

## `nixos/services/system/grafana/dashboards/mail.nix`

The dashboard of the mail node, from what it pushes to the Pushgateway: the mail that flows
through it and the spam it filters, then its health. The node pushes its counters as totals at
least every quarter hour, so a flow is the increase over an hour or a day, which holds several

## `nixos/services/system/grafana/dashboards/vpn.nix`

The dashboard of the VPN nodes, from what they push to the Pushgateway: their health, then the
attacks on them and the traffic through them. A node samples every ten minutes, so a rate of
its own numbers is taken over an hour, which always holds several samples

<!-- /generated -->
