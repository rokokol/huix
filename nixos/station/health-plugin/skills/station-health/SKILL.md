---
name: station-health
description: Read what is broken or getting worse on the station, the owner's PC and laptop, and the mail and VPN nodes, and act on an alert. Use when an alert arrives, or when the owner asks how things are, in any words — "что сломалось", "как там сервер", "всё ли в порядке", "почему пришёл алерт", "живы ли ноды", "сколько места под бэкапы", "is anything broken", "how is the server"
---

# station-health

Every source here is read-only for you. Never restart, reset or clear anything without the owner's word in the chat

## Open problems

`alert list` prints each open problem: key, time it opened, subject, separated by tabs. A problem opens once, is sent by mail, Telegram and to you, and closes by itself when its cause goes. `alert help` says what each key means

- The body of a problem, with the unit's status and its last journal lines when it is a unit, is `/var/lib/alerts/open/<key>/body`
- The history of every problem is `/var/lib/alerts/journal`: time, `OPEN`, `UPDATE` or `RESOLVED`, key, subject, separated by tabs. A problem that opens and closes again and again is the thing to report, even when nothing is open now
- A key `unit:<name>` is a failed unit: read `systemctl status <name>` and the body. The reboot key is quiet: it means a new kernel waits for a reboot, which only the owner decides

## Metrics

Prometheus answers on `http://127.0.0.1:9090`. Ask it with `curl -s --get --data-urlencode 'query=<PromQL>' http://127.0.0.1:9090/api/v1/query`, and read `.data.result`. Grafana draws the same data for the owner at `http://nixos-station:3200`, dashboards Hosts and Guards

| Question | PromQL |
| --- | --- |
| Which watched unit is failed | `node_systemd_unit_state{state="failed"} == 1` |
| How old is each node's newest backup, in seconds | `time() - backup_last_snapshot_timestamp_seconds` |
| Free space for the backups, in bytes | `backup_free_bytes` |
| How long since each node pushed, in seconds | `time() - max by (instance) (push_time_seconds)` |
| Which host or exporter is down | `up == 0` |
| Disks that fail SMART | `smartctl_device_smart_status == 0` |
| Disk space used, by mount | `1 - node_filesystem_avail_bytes / node_filesystem_size_bytes` |
| Syncthing peers that are not connected | `syncthing_connections_active == 0` |
| What a Syncthing folder still needs, in bytes | `syncthing_model_folder_summary{scope="need", type="bytes"}` |

A laptop or PC that is off shows `up == 0`; that alone is not a fault. The thresholds that raise an alert are in the subjects of the alerts, not here

## Answering

Say what is wrong, since when, and what you found in the body, the status or the metrics. Name the one action that would fix it, and ask before you take it
