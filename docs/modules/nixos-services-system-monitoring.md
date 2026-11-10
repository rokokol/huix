---
title: nixos/services/system/monitoring
kind: module
dir: nixos/services/system/monitoring
---

# nixos/services/system/monitoring

<!-- generated: module nixos/services/system/monitoring -->

## [`nixos/services/system/monitoring/alert-mail.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/alert-mail.nix)

Alerts for a host with no desktop to show a notification on, in two levels. A problem is sent
once when it opens and once when it closes, by mail and, where it is on, by Telegram and to an
agent; a daily mail lists what is still open. msmtp becomes the system sendmail, so smartd and
the alerts reach an SMTP relay through it. The relay and the real recipient are private: both
arrive through sops and never enter the store

**Options:** `rokokol.alert-mail.digestTime`, `rokokol.alert-mail.enable`, `rokokol.alert-mail.notify`, `rokokol.alert-mail.sources`, `rokokol.alert-mail.stateDir`, `rokokol.alert-mail.telegram.api`, `rokokol.alert-mail.telegram.enable`, `rokokol.alert-mail.telegram.threadId`

More: [rokokol.alert-mail options](../options/alert-mail.md)

**Units:** `alert-digest`, `alert-reconcile`

## [`nixos/services/system/monitoring/backup-heartbeat.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/backup-heartbeat.nix)

An hourly check that every node behind the restic server pushed recently and that the
backup filesystem keeps its free space. A problem fails the unit, or, with causesFile, goes
to that file; the host decides what either sets off

**Options:** `rokokol.backup-heartbeat.causesFile`, `rokokol.backup-heartbeat.enable`, `rokokol.backup-heartbeat.maxAge`, `rokokol.backup-heartbeat.metricsFile`, `rokokol.backup-heartbeat.minFree`

More: [rokokol.backup-heartbeat options](../options/backup-heartbeat.md)

**Units:** `backup-heartbeat`

## [`nixos/services/system/monitoring/node-exporter.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/node-exporter.nix)

The host's own metrics for the station's Prometheus: CPU, memory, swap, disks, network and the
hwmon sensors. The exporter listens on every address, and tailscale.nix trusts the tailnet
interface, so the tailnet reaches it while the closed firewall keeps every other network out.
A module that measures a thing node_exporter cannot see writes a file into the textfile
directory, and that module enables itself only where the thing exists

**Options:** `rokokol.node-exporter.textfileDir`

More: [rokokol.node-exporter options](../options/node-exporter.md)

## [`nixos/services/system/monitoring/prometheus.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/prometheus.nix)

Prometheus on loopback, for the Grafana beside it. It scrapes every host of this flake over the
tailnet, by the host's name, and takes from each host's own configuration which exporters run
there and on which port: a host that turns an exporter off drops out of its job. A host that is
off gives a gap, not an alert

**Options:** `rokokol.prometheus.enable`, `rokokol.prometheus.retention`

More: [rokokol.prometheus options](../options/prometheus.md)

## [`nixos/services/system/monitoring/pushgateway.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/pushgateway.nix)

A Prometheus Pushgateway that the nodes behind the restic server push their metrics to, and a
check that each of them keeps pushing. The nodes are the users of the restic server's htpasswd,
so no node name is written here: a node signs in with its restic user and may write only the
group whose instance label is that user. Prometheus on this host reads the gateway on loopback

**Options:** `rokokol.pushgateway.backendPort`, `rokokol.pushgateway.causesFile`, `rokokol.pushgateway.enable`, `rokokol.pushgateway.maxSilence`, `rokokol.pushgateway.port`

More: [rokokol.pushgateway options](../options/pushgateway.md)

**Units:** `node-push-watch`

## [`nixos/services/system/monitoring/smartd.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/smartd.nix)

SMART monitoring of every disk the host finds at boot, with desktop alerts. smartd polls every
30 minutes and starts a scheduled self-test in the first poll inside the matching hour. A test
whose hour passed while the host slept or was off starts in the first poll after that

**Units:** `smartd`

<!-- /generated -->
