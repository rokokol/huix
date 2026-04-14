# huix

Ну это мой короче конфиг для NixOS для ПК и для ноута в разных профилях флейка, пон да? Сижу на Hyprland, юзаю nixvim как IDE и часть штук типа Obsidian или Firefox синхронизирую через git/облако, а не декларативно, кривые пакеты и вовсе через flatpack качаю; MATLAB/Python/C++

![Текущее лого](./logo.jpg)

- [ ] Трайнуть stylix
- [ ] Настроить секреты в soapnix
- [ ] Настроить disko

## Что здесь важно

- Репозиторий рассчитан на `x86_64-linux` и использует только flake-based workflow
- Базовый пакетный набор идет из `nixos-unstable`
- Дополнительно проброшен `nixpkgs-stable` как `pkgs.stable`
- Для ПК есть отдельный CUDA overlay, который дает доступ к `pkgs.cuda.*`, он, внезаптно, собирает приложения с поддержкой CUDA
- Home Manager подключен внутрь `nixosSystem` через `home-manager.nixosModules.home-manager`, то есть отдельного HM deployment-потока здесь нет
- `home-manager.useGlobalPkgs = true`, поэтому системный и пользовательский слой используют один и тот же пакетный набор и overlays

## Хосты

| Host | System entrypoint | HM entrypoint | Ключевые отличия |
| --- | --- | --- | --- |
| `nixos-pc` | `nixos/configuration-pc.nix` | `home-manager/home-pc.nix` | NVIDIA/CUDA, `ollama-cuda`, ComfyUI, Open WebUI, Docker, virtualization, SearxNG, printing, tablet, Arduino, Cachix, NTFS mount `govno` |
| `nixos-laptop` | `nixos/configuration-laptop.nix` | `home-manager/home-laptop.nix` | CPU-only `ollama`, Bluetooth, power tuning, более легкий desktop stack |

Дополнительное различие по Python/ML:

- ПК использует `pkgs.stable.python3` с бинарными `torch*`, чтобы не собирать тяжелый ML-стек локально
- Ноутбук использует обычный `pkgs.python3Packages` без CUDA

## Где менять что

| Что нужно поменять | Куда идти |
| --- | --- |
| Общую flake-архитектуру, inputs, overlays, `specialArgs` | `flake.nix` |
| Импорт модулей конкретного хоста | `nixos/configuration-pc.nix`, `nixos/configuration-laptop.nix` |
| Системные пакеты, system-wide toggles, браузер, Steam, Hyprland enable | `nixos/pc/packages.nix`, `nixos/laptop/packages.nix` |
| Базовые host settings: hostname, user, locale, Nix GC, файловые системы | `nixos/pc/system.nix`, `nixos/laptop/system.nix` |
| Аппаратные настройки, boot, GPU, sound, keyboard | `nixos/pc/*`, `nixos/laptop/*` |
| Reusable system services | `nixos/services/*.nix` |
| Локальные шрифты и их подключение | `nixos/fonts/*` |
| Пользовательские пакеты desktop-слоя | `home-manager/desktop/common-packages.nix`, `home-manager/desktop/pc-packages.nix`, `home-manager/desktop/laptop-packages.nix` |
| Пользовательские директории, bookmarks, env vars, dotfiles | `home-manager/desktop/user-pc.nix`, `home-manager/desktop/user-laptop.nix` |
| Hyprland, Waybar, hypridle, session-скрипты | `home-manager/hyprland/*` |
| Конфиги отдельных программ | `home-manager/programs/*` |
| Neovim через nixvim | `home-manager/programs/nixvim/*` |

## Сервисы

Общие для обоих хостов:

- `file-manager.nix`
- `wl-clip-persist.nix`
- `sddm.nix`
- `jupyter.nix`
- `ssh-askpass.nix`
- `amnezia-vpn.nix`
- `syncting.nix`
- `ollama.nix`
- `tor.nix`

Только для ПК:

- `docker.nix`
- `virtualization.nix`
- `searxng.nix`
- `printing.nix`
- `tablet.nix`
- `cachix.nix`
- `arduino.nix`
- `nix-ld.nix`
- `openwebui.nix`
- `comfyui.nix`

## Operational Notes

- На ПК ожидается NTFS-раздел с label `govno`, который монтируется в `/home/rokokol/govno`.
- На ПК `xdg.userDirs` для `Music`, `Documents`, `Pictures`, `Videos` указывают именно в `/home/rokokol/govno`, поэтому отсутствие этого mount не ломает boot из-за `nofail`, но ломает часть пользовательских путей
- `HUIX` экспортируется как session variable и используется в shell aliases и скриптах
- `system.stateVersion` и `home.stateVersion` сейчас зафиксированы на `25.11`

### Обновить hardware config

При изменениях железа:

```sh
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

## Отдельные заметки

MATLAB в этом репозитории запускается так:

```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

