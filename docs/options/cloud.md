---
title: Опции rokokol.cloud
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.cloud

<!-- generated: option cloud -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `drive-backup.cloud.configFile` | `/var/lib/restic-cloud/rclone.conf` | `/var/lib/restic-cloud/rclone.conf` | `/var/lib/restic-cloud/rclone.conf` | Private writable rclone configuration after explicit OAuth authorization |
| `drive-backup.cloud.destination` | `drive-backup:backups/restic` | `drive-backup:backups/restic` | `drive-backup:backups/restic` | Dedicated rclone path for the encrypted restic mirror |
| `drive-backup.cloud.enable` | нет | нет | да | Whether to enable a daily cloud mirror of every restic repository. |
| `drive-backup.cloud.maxAge` | `129600` | `129600` | `129600` | Maximum age of a successful cloud mirror, in seconds |
| `drive-backup.cloud.onCalendar` | `*-*-* 04:30:00` | `*-*-* 04:30:00` | `*-*-* 04:30:00` | Cloud mirror schedule in systemd calendar syntax |

Объявлено в: `nixos/services/tools/drive-backup.nix`

<!-- /generated -->
