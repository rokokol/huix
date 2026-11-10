---
title: Опции rokokol.drive-backup
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.drive-backup

<!-- generated: option drive-backup -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.drive-backup.cloud.configFile` | `/var/lib/restic-cloud/rclone.conf` | `/var/lib/restic-cloud/rclone.conf` | `/var/lib/restic-cloud/rclone.conf` | Private writable rclone configuration after explicit OAuth authorization |
| `rokokol.drive-backup.cloud.destination` | `drive-backup:backups/restic` | `drive-backup:backups/restic` | `drive-backup:backups/restic` | Dedicated rclone path for the encrypted restic mirror |
| `rokokol.drive-backup.cloud.enable` | нет | нет | да | Whether to enable a daily cloud mirror of every restic repository. |
| `rokokol.drive-backup.cloud.maxAge` | `129600` | `129600` | `129600` | Maximum age of a successful cloud mirror, in seconds |
| `rokokol.drive-backup.cloud.onCalendar` | `*-*-* 04:30:00` | `*-*-* 04:30:00` | `*-*-* 04:30:00` | Cloud mirror schedule in systemd calendar syntax |
| `rokokol.drive-backup.enable` | да | да | да | Whether to enable Google Drive backup credentials. |

Объявлено в: [`nixos/services/tools/drive-backup.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/drive-backup.nix)

<!-- /generated -->
