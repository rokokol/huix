<div align="center">

<img src="../assets/laptop-wallpaper.png" alt="обои ноута" width="380"/>

<em>тут живёт всё, что делает рабочий стол крутым</em>

</div>

# Home Manager-слой

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![hyprland](https://img.shields.io/badge/hyprland-рабочий_стол-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white)](desktop/hyprland/README.md)
[![programs](https://img.shields.io/badge/programs-программы-7E57C2?style=for-the-badge)](programs/README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](programs/nixvim/README.md)
[![rofi](https://img.shields.io/badge/rofi-лаунчер-EE2A7B?style=for-the-badge)](programs/rofi/README.md)

Всё, что про пользовательское окружение: конфиги приложений, шелл, тема, Hyprland/Waybar, per-user пакеты и systemd-user юниты. Системное (boot, железо, сервисы) — это в [`nixos/`](../nixos/README.md)

HM подключён не отдельным потоком, а как NixOS-модуль с `useGlobalPkgs = true`, поэтому системный и пользовательский слой делят один пакетный набор и overlays. Важное следствие — `nixpkgs.config` и `nixpkgs.overlays` внутри HM-модуля игнорируются, вся конфигурация пакетов живёт в [`flake.nix`](../flake.nix)

## Что внутри

| Файл / каталог | Что внутри |
| --- | --- |
| `home-pc.nix` / `home-laptop.nix` | точки входа per-host: весь вход `custom.*` (hyprland, waybar, packages, dataDir) + btop-пакет |
| `desktop/user.nix` | XDG-директории, закладки, tmpfiles, env; база данных хоста — опция `custom.home.dataDir` |
| `desktop/sync.nix` | systemd-таймер авто-синка конфига (`scripts/sync.sh`, ежечасно) |
| [`desktop/hyprland/`](desktop/hyprland/README.md) | `hyprland.conf`, единый `hyprland.nix` с опциями `custom.hyprland.*`, `services/`: waybar, mako, hypridle, обои-коллажер |
| `desktop/packages/` | `packages.nix`: общие пакеты + группы с флагами `custom.packages.{pc,laptop}` + `mime-apps` |
| `desktop/theme/` | курсор, GTK/qt-тема, дефолты |
| `programs/` | конфиги отдельных программ, см. [programs/README.md](programs/README.md) |

## Где что менять

- пользовательские пакеты — `desktop/packages/packages.nix`: общий блок (оба хоста) и группы `custom.packages.{pc,laptop}` (per-host)
- XDG-директории, закладки, env — `desktop/user.nix`; что включено на хосте — `home-<host>.nix`
- Hyprland, Waybar, hypridle, обои, mako — `desktop/hyprland/*`
- тема (cursor, GTK, qt) — `desktop/theme/*`
- конфиги программ (kitty, zsh, starship, git, ssh, btop, direnv, rofi, thunar, zen, nixvim) — `programs/*`

## Тонкости

- **тема свет/тьма управляется в рантайме, не декларативно** — `scripts/toggle-theme.sh` (бинд `SUPER+A`) флипает `color-scheme`+`gtk-theme` в dconf и пишет выбор в `~/.local/state/huix/theme`. Не клади `color-scheme`/`gtk-theme` в `theme.nix` `dconf.settings` и не ставь `gtk.theme` — иначе `dconf load` на каждом ребилде будет сбивать рантайм-выбор обратно в светлую
- `home.stateVersion` зафиксирован на `25.11` — не трогай без явной миграции
- `backupFileExtension = "bak-${lastModified}"` — каждый ребилд с новой ревизии флейка плодит свой `.bak` в `$HOME`, периодически чисти

## Применение

Подключается из `nixos/configuration-<host>.nix` через `home-manager.nixosModules.home-manager`

