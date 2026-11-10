---
title: Хост nixos-laptop
kind: host
hosts: [nixos-laptop]
---

# Хост nixos-laptop

<!-- generated: host nixos-laptop -->

Система: `x86_64-linux`

Настраивается в [`nixos/configuration-laptop.nix`](https://github.com/rokokol/huix/blob/master/nixos/configuration-laptop.nix)

**Службы из этого репозитория:** `NetworkManager-wait-online`, `smartd`, `syncthing`, `syncthing-init`, `zram-metrics`

**Таймеры:** `zram-metrics`

**Файрвол открывает:** TCP `22000`, UDP `21027`, `22000`, `41641`

**Секреты sops по имени:** `drive-backup-client`, `hindsight-client-token`, `opencode-go-pi-key`, `openrouter-pi-key`, `radicale-password-rokokol`, `syncthing-cert-nixos-laptop`, `syncthing-key-nixos-laptop`

Переменные сессии

| Переменная | Значение |
| --- | --- |
| `COLOR_SCHEME_KEY` | `/org/gnome/desktop/interface/color-scheme` |
| `CONTRIB_HOME` | `/home/rokokol/.local/share/pi-shared/skill-state/contributing` |
| `DARK_SCHEME` | `prefer-dark` |
| `DARK_THEME` | `Gruvbox-Dark` |
| `EDITOR` | `nvim` |
| `GTK2_RC_FILES` | `/home/rokokol/.gtkrc-2.0` |
| `GTK4_DARK_CSS` | `/nix/store/85h2fb72npr5r1cdv5q1rzfgcaxyd9im-gruvbox-gtk-theme-0-unstable-2025-10-23/share/themes/Gruvbox-Dark/gtk-4.0/gtk-colors.css` |
| `GTK4_LIGHT_CSS` | `/nix/store/85h2fb72npr5r1cdv5q1rzfgcaxyd9im-gruvbox-gtk-theme-0-unstable-2025-10-23/share/themes/Gruvbox-Light/gtk-4.0/gtk-colors.css` |
| `GTK_THEME_KEY` | `/org/gnome/desktop/interface/gtk-theme` |
| `HUIX` | `/home/rokokol/huix` |
| `HUIX_TABLET_SIGNAL` | `10` |
| `HUIX_TABLET_SWITCH` | `Intel Virtual Switches` |
| `LIGHT_SCHEME` | `prefer-light` |
| `LIGHT_THEME` | `Gruvbox-Light` |
| `LOCALE_ARCHIVE_2_27` | `/nix/store/00s4gff16566pz4z1ydragxa1dra03cz-glibc-locales-2.44-57/lib/locale/locale-archive` |
| `MY_WIKI` | `/home/rokokol/myWiki` |
| `NIXOS_OZONE_WL` | `1` |
| `NIX_XDG_DESKTOP_PORTAL_DIR` | `/etc/profiles/per-user/rokokol/share/xdg-desktop-portal/portals` |
| `PI_TELEMETRY` | `0` |
| `PROJECTS_DIR` | `/home/rokokol/Projects` |
| `QT_QPA_PLATFORMTHEME` | `xdgdesktopportal` |
| `SP_HOME` | `/home/rokokol/.local/share/pi-shared/skill-state/super-productivity` |
| `SP_TOKEN_FILE` | `/home/rokokol/.config/super-productivity-skill/secrets/token` |
| `STARSHIP_CONFIG` | `/home/rokokol/.config/starship.toml` |
| `SYNC_REMOTES` | `/home/rokokol/.config/huix/sync-remotes` |
| `TERMINAL` | `kitty` |
| `THUNARX_DIRS` | `/run/current-system/sw/lib/thunarx-3` |
| `VISUAL` | `nvim` |
| `WAYBAR_NOTIF_SIGNAL` | `9` |
| `XCURSOR_SIZE` | `32` |
| `XCURSOR_THEME` | `Sayori-Cursor-V2` |
| `XDG_DOCUMENTS_DIR` | `/home/rokokol/Documents` |
| `XDG_DOWNLOAD_DIR` | `/home/rokokol/Downloads` |
| `XDG_MUSIC_DIR` | `/home/rokokol/myWiki/00. Вложения/02. Music` |
| `XDG_PICTURES_DIR` | `/home/rokokol/Pictures` |
| `XDG_PROJECTS_DIR` | `/home/rokokol/Projects` |
| `XDG_VIDEOS_DIR` | `/home/rokokol/Videos` |

<!-- /generated -->
