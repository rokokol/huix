---
title: Опции rokokol.alert-mail
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.alert-mail

<!-- generated: option alert-mail -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `alert-mail.digestTime` | `09:00` | `09:00` | `09:00` | Time of day of the mail that lists every problem still open |
| `alert-mail.enable` | нет | нет | да | Whether to enable alert e-mail through an SMTP relay. |
| `alert-mail.notify` | — | — | — | Command that takes one line of text as its argument and hands it to an agent |
| `alert-mail.sources` |  |  | `backup=/run/backup-heartbeat/causes`, `grafana=/var/lib/grafana-alerts/causes`, `node=/run/node-push-watch/causes` | Files of causes, by source name, each written by a check: one cause a line, a key, a
tab and a subject. Each cause is a problem of its own under <source>:<key>, opened
when the file lists it and closed when it no longer does
 |
| `alert-mail.stateDir` | `/var/lib/alerts` | `/var/lib/alerts` | `/var/lib/alerts` | Directory of the open problems and their journal |

Объявлено в: `nixos/services/system/monitoring/alert-mail.nix`

<!-- /generated -->
