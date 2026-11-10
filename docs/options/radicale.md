---
title: Опции rokokol.radicale
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.radicale

<!-- generated: option radicale -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `radicale.dataDir` | — | — | `/srv/backup/radicale` | Subvolume of the calendars, on the filesystem mounted at `mountPoint` |
| `radicale.enable` | нет | нет | да | Whether to enable the Radicale CalDAV server. |
| `radicale.localUrl` | `http://127.0.0.1:5233/` | `http://127.0.0.1:5233/` | `http://127.0.0.1:5233/` | Root URL of the server for a client on this host. On the host itself its name resolves to
loopback, which the tailnet site refuses, so the client goes to Radicale directly
 |
| `radicale.mountPoint` | — | — | `/srv/backup` | Mountpoint of the filesystem with `dataDir`; the server does not start without it |
| `radicale.owner` | `rokokol` | `rokokol` | `rokokol` | Login whose home holds the calendars |
| `radicale.sharedWith` | — | — | `mya` | Logins that read, write and make calendars in the home of `owner` |
| `radicale.subvolumes` | — | — | `radicale` | Subvolumes of the backup filesystem, as paths inside `mountPoint`, for the disk layout to make |
| `radicale.url` | `http://nixos-laptop:5232/` | `http://nixos-pc:5232/` | `http://nixos-station:5232/` | Root URL of the server inside the tailnet, which a CalDAV client starts from |

Объявлено в: `nixos/services/tools/radicale.nix`

<!-- /generated -->
