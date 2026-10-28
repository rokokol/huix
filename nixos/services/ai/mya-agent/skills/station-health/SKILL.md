---
name: station-health
description: Read what is broken or getting worse on the station, the owner's PC and laptop, and the mail and VPN nodes, log in to a node to read its logs and state, and act on an alert. Use when an alert arrives, when the owner asks how things are, or when he asks to look at a node, in any words — "что сломалось", "как там сервер", "всё ли в порядке", "почему пришёл алерт", "живы ли ноды", "сколько места под бэкапы", "зайди на ноду", "посмотри логи на сервере", "что в очереди почты", "кого забанил fail2ban", "is anything broken", "how is the server", "check the logs on the node"
---

# station-health

Every source here is read-only for you. Never restart, reset or clear anything without the owner's word in the chat

## Open problems

`alert list` prints each open problem: key, time it opened, subject, separated by tabs. A problem opens once, is sent by mail, Telegram and to you, and closes by itself when its cause goes. `alert help` says what each key means

- The body of a problem, with the unit's status and its last journal lines when it is a unit, is `@alertState@/open/<key>/body`
- The history of every problem is `@alertState@/journal`: time, `OPEN`, `UPDATE` or `RESOLVED`, key, subject, separated by tabs. A problem that opens and closes again and again is the thing to report, even when nothing is open now
- A key `backup:<cause>` is one backup repository that is stale or missing, or the backup space running low; `node:<node>-<cause>` is a node that went silent or a problem the node reports of itself, in its own words. Each closes by itself once its cause is gone
- A key `unit:<name>` is a failed unit: read `systemctl status <name>`, the body, and `journalctl -u <name> -n 200` when the body's lines are too few. The reboot key is quiet: it means a new kernel waits for a reboot, which only the owner decides

## Metrics

Prometheus answers on `@prometheus@`. Ask it with `curl -s --get --data-urlencode 'query=<PromQL>' @prometheus@/api/v1/query`, and read `.data.result`. Grafana draws the same data for the owner at `@grafana@`, dashboards @dashboards@

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

An empty `systemctl --failed` is not a health verdict: it never reads the alert state. Read the open problems before you call a host healthy

## Backups

The backup checks take the names they expect from the restic server's htpasswd: each user there is a repository that must hold a fresh snapshot, and a node that must push its metrics, except these users, which back up from this host and push nothing: @localUsers@

- A name new to the htpasswd opens `no snapshot at all` and `never pushed` in the same second, on the first check after an activation. That is a setup not yet finished, not lost data: say so, and name the job that has not run
- `backup_last_snapshot_timestamp_seconds` of 0 means no snapshot ever, not the epoch
- A missing repository is created by its client's own first run, so the one action is to start that client's unit once

## Spend

- The `hermes_*` series are sums over the whole session store, and no restart resets them: a figure per hour is the difference of two samples
- `hermes_cost_usd` is Hermes' estimate wherever the provider reported no cost, so it is not a bill. The bill is OpenRouter's: `openrouter_key_usage_daily_usd`, `openrouter_key_usage_monthly_usd`, `openrouter_balance_usd`, `openrouter_budget_remaining_usd`
- OpenRouter's day is the UTC day, not the station's local one, so its daily figure and a local day's sum differ by design. Say which day you mean

## On the nodes

When the metrics and the body of a problem do not explain it, log in to the node. The nodes are the `instance` labels of `push_time_seconds`, and each label is the node's tailnet name: `ssh <instance> '<command>'`. You log in as an observer, which reads the journal and `/var/log` and changes nothing

- What runs and what failed: `systemctl --failed`, `systemctl status <unit>`, `journalctl -u <unit> -n 200`, `journalctl -p warning --since -1d`
- As root, only what `sudo -n -l` lists on that node, with exactly the arguments it lists. Run them with `sudo -n`; any other command or argument is refused
- On the mail node, the queue: `postqueue -p`

The panel's database, the Xray config, the mailboxes and the secrets are closed to you. When something is refused, say so and stop: never look for another way in

## Answering

Say what is wrong, since when, and what you found in the body, the status or the metrics. Name the one action that would fix it, and ask before you take it
