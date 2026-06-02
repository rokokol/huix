# huix

Ну это мой короче конфиг для NixOS для ПК и для ноута в разных профилях флейка, пон да? Сижу на Hyprland, юзаю nixvim как IDE и часть штук типа Obsidian или Zen синхронизирую через git/облако, а не декларативно, кривые пакеты и вовсе через flatpak качаю; MATLAB/Python/C++

![Текущее лого](./assets/logo.jpg)

## TODO

- [ ] Трайнуть stylix
- [ ] Настроить секреты в soapnix
- [ ] Настроить disko

## Что здесь важно

- Репозиторий рассчитан на `x86_64-linux` и использует только flake-based workflow
- Базовый пакетный набор идет из `nixos-unstable`
- Дополнительно проброшен `nixpkgs-stable` (25.11) как `pkgs.stable` через overlay
- Для ПК есть отдельный CUDA overlay, который дает доступ к `pkgs.cuda.*`, он, внезапно, собирает приложения с поддержкой CUDA
- Home Manager подключен внутрь `nixosSystem` через `home-manager.nixosModules.home-manager`, то есть отдельного HM deployment-потока здесь нет
- `home-manager.useGlobalPkgs = true`, поэтому системный и пользовательский слой используют один и тот же пакетный набор и overlays
- `commonArgs` (включает `rokokolName`, `huixDir`, `govnoDir`, `system`, `inputs`) пробрасывается и в системные модули через `specialArgs`, и в HM через `extraSpecialArgs`

## Хосты

| Host | System entrypoint | HM entrypoint | Ключевые отличия |
| --- | --- | --- | --- |
| `nixos-pc` | `nixos/configuration-pc.nix` | `home-manager/home-pc.nix` | NVIDIA/CUDA, `ollama-cuda`, ComfyUI, Open WebUI, Docker, virtualization, SearxNG, printing, tablet, Arduino, NTFS-маунт `govno`, `btop-cuda`, Steam, нагруженный creative-стек (Krita, OBS, Darktable, Kdenlive…) |
| `nixos-laptop` | `nixos/configuration-laptop.nix` | `home-manager/home-laptop.nix` | CPU-only `ollama-cpu`, Bluetooth, powertop, Tor (через webtunnel), более легкий desktop stack |

Дополнительное различие по Python/ML:

- ПК использует `pkgs.stable.python3` с бинарными `torch*` (см. `nixos/services/tools/jupyter.nix`), чтобы не собирать тяжелый ML-стек локально, CUDA включается через `custom.jupyter.withCuda`
- Ноутбук использует тот же модуль Jupyter, но без CUDA

## Где менять что

| Что нужно поменять | Куда идти |
| --- | --- |
| Общую flake-архитектуру, inputs, overlays, `specialArgs` | `flake.nix` |
| Импорт модулей конкретного хоста | `nixos/configuration-pc.nix`, `nixos/configuration-laptop.nix` |
| Общие системные модули (desktop, fonts) | `nixos/default.nix`, `nixos/desktop/*`, `nixos/fonts/*` |
| Host-specific опции, boot, hardware, GPU, клавиатуру | `nixos/pc/*`, `nixos/laptop/*` |
| Базовые host settings: hostname, user, locale, Nix GC, файловые системы | `nixos/pc/system.nix`, `nixos/laptop/system.nix` |
| Набор сервисов, включенных на хосте | `nixos/services/services-pc.nix`, `nixos/services/services-laptop.nix` |
| Конкретный системный сервис | `nixos/services/<категория>/*.nix` |
| Пользовательские пакеты desktop-слоя | `home-manager/desktop/packages/packages-common.nix`, `packages-pc.nix`, `packages-laptop.nix` |
| Пользовательские директории, bookmarks, env vars | `home-manager/desktop/user-pc.nix`, `home-manager/desktop/user-laptop.nix` |
| Авто-sync конфига (`scripts/sync.sh` + systemd-таймер) | `home-manager/desktop/sync.nix` |
| Hyprland, Waybar, hypridle, обои, mako | `home-manager/desktop/hyprland/*` |
| Тема (cursor, GTK, qt) | `home-manager/desktop/theme/*` |
| Конфиги отдельных программ (kitty, zsh, starship, git, ssh, btop, direnv, rofi, thunar, zen) | `home-manager/programs/*` |
| Neovim через nixvim | `home-manager/programs/nixvim/*` |

## Структура репозитория

```
huix/
├── flake.nix / flake.lock         # entrypoint, inputs, overlays, два nixosConfigurations
├── nixos/                          # NixOS-слой
│   ├── configuration-pc.nix        # ПК: imports + ollama-cuda
│   ├── configuration-laptop.nix    # Ноут: imports + ollama-cpu
│   ├── default.nix                 # общий desktop + fonts
│   ├── desktop/                    # core-options, portals
│   ├── fonts/                      # шрифты системного уровня
│   ├── pc/                         # host-specific: boot, hardware, nvidia, keyboard, sound, system, options
│   ├── laptop/                     # host-specific: boot, hardware, keyboard, system, options
│   └── services/
│       ├── services-pc.nix         # агрегатор сервисов для ПК
│       ├── services-laptop.nix     # агрегатор сервисов для ноута
│       ├── ai/                     # comfyui, ollama, openwebui
│       ├── desktop/                # amnezia-vpn, file-manager, sddm, ssh-askpass, wl-clip-persist
│       ├── devices/                # printer, tablet
│       ├── system/                 # cachix, nix-ld
│       ├── tools/                  # jupyter, libre-translate, searxng, syncthing
│       └── utils/                  # arduino, docker, tor, virtualization, zapret
├── home-manager/                   # Home Manager-слой
│   ├── home-pc.nix / home-laptop.nix
│   ├── desktop/
│   │   ├── user-pc.nix / user-laptop.nix    # XDG, bookmarks, tmpfiles, env
│   │   ├── sync.nix                          # systemd-юнит для авто-sync
│   │   ├── hyprland/                         # hyprland-pc/laptop + services/ (waybar, mako, hypridle, обои)
│   │   ├── packages/                         # packages-common + per-host + mime-apps
│   │   └── theme/                            # cursor, theme, default
│   └── programs/
│       ├── cli/                              # btop, direnv, git, ssh
│       ├── nixvim/                           # см. nixvim/README.md
│       ├── rofi/                             # см. rofi/README.md
│       ├── term/                             # kitty, starship, zsh
│       ├── thunar.nix
│       └── zen.nix
├── scripts/                        # рукописные shell-скрипты (sync, обои, rofi-хелперы)
├── assets/                         # обои, лого
├── CLAUDE.md                       # шпаргалка по архитектуре и правилам репо для агентов
└── README.md                       # ты здесь
```

## Сервисы

Общие для обоих хостов (`services-pc.nix` ∩ `services-laptop.nix`):

- `ai/ollama.nix` (на ПК подменяется на `ollama-cuda` в `configuration-pc.nix`)
- `desktop/amnezia-vpn.nix`
- `desktop/file-manager.nix`
- `desktop/sddm.nix`
- `desktop/ssh-askpass.nix`
- `desktop/wl-clip-persist.nix`
- `system/cachix.nix`
- `tools/jupyter.nix` (на ПК с CUDA)
- `tools/libre-translate.nix`
- `tools/syncthing.nix`
- `utils/docker.nix`

Только для ПК:

- `ai/comfyui.nix` (через flakehub `comfyui-nix`)
- `ai/openwebui.nix`
- `devices/printer.nix`
- `devices/tablet.nix`
- `system/nix-ld.nix`
- `tools/searxng.nix` (+ nginx-фронт на localhost)
- `utils/arduino.nix`
- `utils/virtualization.nix` (libvirtd + KVM/AMD + vfio)

Только для ноута:

- `utils/tor.nix` (webtunnel-bridges)

## Порты и биндинги

Все сервисы биндятся на `127.0.0.1`, наружу ничего не торчит (firewall не открыт).

| Сервис | Порт | Биндинг |
| --- | --- | --- |
| Ollama | 11434 | 127.0.0.1 |
| Open WebUI (PC) | 8088 | 127.0.0.1 |
| ComfyUI (PC) | 8188 | 127.0.0.1 |
| SearxNG (PC, за nginx) | 9000 | 127.0.0.1 |
| Jupyter Lab | 8888 | 127.0.0.1 |
| LibreTranslate | 5000 | default |
| Syncthing GUI | 8384 | 127.0.0.1 |

Порты экспортируются как session variables (`OPEN_WEBUI_PORT`, `COMFYUI_PORT`, `SYNCTHING_PORT`, `LIBRE_TRANSLATE_PORT`) — удобно использовать в скриптах и алиасах.

## Скрипты

`scripts/` — рукописные shell-обертки, рассчитанные на путь `$HUIX/scripts`:

- `sync.sh` — `git pull --rebase --autostash` → `add --all` → `commit` → `push`. Запускается ежечасно systemd-таймером из `home-manager/desktop/sync.nix`. **Внимание**: коммитит и пушит вообще все нестейдженные изменения, поэтому не оставляй в репо что-то, чего не хочешь видеть в истории.
- `random_wallpaper.sh` — рандомные обои для Hyprland
- `toggle_theme.sh` — переключение rofi между light/dark
- `rofi-clipboard.sh`, `rofi-libre.sh`, `rofi_wooordhunt.sh` — кастомные rofi-режимы (clip, LibreTranslate, словарь)
- `colorpicker.sh` — pipette через hyprpicker
- `pin-screen.sh` — закрепить окно поверх остальных
- `normalize-nix-entry-style.sh` — массовая нормализация заголовков модулей

## Operational Notes

- На ПК ожидается NTFS-раздел с label `govno`, который монтируется в `/home/rokokol/govno` через `fileSystems` в `nixos/pc/system.nix` (с `nofail`)
- На ПК `xdg.userDirs` для `Music`, `Documents`, `Pictures`, `Videos` указывают именно в `/home/rokokol/govno`, поэтому отсутствие этого mount **не ломает boot** (из-за `nofail`), но ломает часть пользовательских путей
- `HUIX` экспортируется как session variable (`home-manager/desktop/packages/packages-common.nix`) и используется в shell aliases и скриптах
- `home-manager.backupFileExtension = "bak"` — фиксированное расширение, поэтому повторный rebuild может упереться в существующий `*.bak`-файл; в этом случае надо снести старые `.bak` руками
- `system.stateVersion` и `home.stateVersion` сейчас зафиксированы на `25.11`
- Сборка ускоряется кэшами `cuda-maintainers.cachix.org` (PC) и `comfyui.cachix.org` (PC), trusted-users — `@wheel`

## Build / Switch / Update

```sh
# ПК
sudo nixos-rebuild switch --flake .#nixos-pc

# Ноут
sudo nixos-rebuild switch --flake .#nixos-laptop

# Сборка без переключения
rebuild # или rebuilds для зеркала только от Яндекса, если проблемы с сетью

# Обновить все inputs
nix flake update

# Обновить один input
nix flake update <name>
```

### Обновить hardware config

При изменениях железа:

```sh
sudo nixos-generate-config --show-hardware-config > nixos/<host>/hardware-configuration.nix
```

## Отдельные заметки

MATLAB в этом репозитории запускается так:

```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```
