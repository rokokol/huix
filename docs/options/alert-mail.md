---
title: rokokol.alert-mail options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.alert-mail options

<!-- generated: option alert-mail -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.alert-mail.digestTime` | `09:00` | `09:00` | `09:00` | Time of day of the mail that lists every problem still open |
| `rokokol.alert-mail.enable` | no | no | yes | Whether to enable alert e-mail through an SMTP relay. |
| `rokokol.alert-mail.notify` | — | — | — | Command that takes one line of text as its argument and hands it to an agent |
| `rokokol.alert-mail.sources` |  |  | `backup=/run/backup-heartbeat/causes`, `grafana=/var/lib/grafana-alerts/causes`, `node=/run/node-push-watch/causes` | Files of causes, by source name, each written by a check: one cause a line, a key, a tab and a subject. Each cause is a problem of its own under <source>:<key>, opened when the file lists it and closed when it no longer does |
| `rokokol.alert-mail.stateDir` | `/var/lib/alerts` | `/var/lib/alerts` | `/var/lib/alerts` | Directory of the open problems and their journal |
| `rokokol.alert-mail.telegram.api` | `https://api.telegram.org` | `https://api.telegram.org` | `https://api.telegram.org` | Base URL of the Telegram Bot API |
| `rokokol.alert-mail.telegram.enable` | no | no | yes | Whether to enable a copy of each alert in the owner's Telegram, through the bot whose token and the owner's chat id are the sops secrets telegram-bot-token and telegram-owner-chat-id . |
| `rokokol.alert-mail.telegram.threadId` | — | — | `1089071` | Topic of the forum in the owner's chat that carries the alerts, passed as the Bot API's `message_thread_id`, which the API accepts for forum supergroups alone. A message sent without it reaches the chat's General topic, while the agent's own replies go to the topic its gateway is configured with |

Declared in: [`nixos/services/system/monitoring/alert-mail.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/monitoring/alert-mail.nix)

<!-- /generated -->
