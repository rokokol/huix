# huix

Flake-репозиторий с двумя NixOS-хостами (`nixos-pc` и `nixos-laptop`), где системный слой и Home Manager собираются вместе из одного источника правды.

![Текущее лого](./logo.jpg)

## Что здесь важно

- Репозиторий рассчитан на `x86_64-linux` и использует только flake-based workflow.
- Базовый пакетный набор идет из `nixos-unstable`.
- Дополнительно проброшен `nixpkgs-stable` как `pkgs.stable`.
- Для ПК есть отдельный CUDA overlay, который дает доступ к `pkgs.cuda.*`.
- Home Manager подключен внутрь `nixosSystem` через `home-manager.nixosModules.home-manager`, то есть отдельного HM deployment-потока здесь нет.
- `home-manager.useGlobalPkgs = true`, поэтому системный и пользовательский слой используют один и тот же пакетный набор и overlays.

## Хосты

| Host | System entrypoint | HM entrypoint | Ключевые отличия |
| --- | --- | --- | --- |
| `nixos-pc` | `nixos/configuration-pc.nix` | `home-manager/home-pc.nix` | NVIDIA/CUDA, `ollama-cuda`, ComfyUI, Open WebUI, Docker, virtualization, SearxNG, printing, tablet, Arduino, Cachix, NTFS mount `govno` |
| `nixos-laptop` | `nixos/configuration-laptop.nix` | `home-manager/home-laptop.nix` | CPU-only `ollama`, Bluetooth, power tuning, более легкий desktop stack |

Дополнительное различие по Python/ML:

- ПК использует `pkgs.stable.python3` с бинарными `torch*`, чтобы не собирать тяжелый ML-стек локально.
- Ноутбук использует обычный `pkgs.python3Packages` без CUDA.

## Как собран flake

Поток сборки выглядит так:

1. `flake.nix` задает inputs, overlays, общие аргументы (`rokokolName`, `huixDir`, `govnoDir`, `system`) и собирает оба `nixosConfigurations`.
2. `nixos/configuration-*.nix` подключают системные модули хоста и reusable-сервисы.
3. Через `home-manager.nixosModules.home-manager` в тот же system closure добавляется `home-manager/home-*.nix`.
4. `home-manager/home-*.nix` подтягивают Hyprland, desktop layer и конфиги отдельных программ.

Практическое следствие: если настройка относится к приложению пользователя, она почти наверняка должна лежать в `home-manager/`, а не в `nixos/`.

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

## Слои пакетов

В репозитории уже есть явное разделение ответственности, его лучше не ломать:

- `nixos/*/packages.nix`: системные пакеты и системные фичи хоста.
- `home-manager/desktop/common-packages.nix`: общий пользовательский desktop stack.
- `home-manager/desktop/pc-packages.nix` и `home-manager/desktop/laptop-packages.nix`: host-specific пользовательские пакеты.
- `home-manager/hyprland/hyprland-packages.nix`: только то, что нужно самой Hyprland-сессии и связанным скриптам.

Если пакет нужен только в UI-сессии пользователя, его лучше класть в Home Manager, а не в `environment.systemPackages`.

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

## Команды

Проверить, что конфиг собирается, без переключения:

```sh
nix build .#nixosConfigurations.nixos-pc.config.system.build.toplevel
nix build .#nixosConfigurations.nixos-laptop.config.system.build.toplevel
```

Применить конфиг:

```sh
sudo nixos-rebuild switch --flake .#nixos-pc
sudo nixos-rebuild switch --flake .#nixos-laptop
```

Обновить inputs:

```sh
nix flake update
```

В `zsh` есть alias:

```sh
rebuild
```

Он разворачивается в `sudo nixos-rebuild switch --flake /home/rokokol/huix`.

## Operational Notes

- На ПК ожидается NTFS-раздел с label `govno`, который монтируется в `/home/rokokol/govno`.
- На ПК `xdg.userDirs` для `Music`, `Documents`, `Pictures`, `Videos` указывают именно в `/home/rokokol/govno`, поэтому отсутствие этого mount не ломает boot из-за `nofail`, но ломает часть пользовательских путей.
- `ssh-askpass` настроен через `rofi`, см. `nixos/services/ssh-askpass.nix`.
- `home.file.".face".source = ../../logo.jpg` используется в обоих Home Manager entrypoint'ах.
- `HUIX` экспортируется как session variable и используется в shell aliases и скриптах.
- `system.stateVersion` и `home.stateVersion` сейчас зафиксированы на `25.11`.

## Типовые изменения

### Добавить новый system service

1. Создать или изменить модуль в `nixos/services/`.
2. Подключить его в нужном `nixos/configuration-*.nix`.
3. Собрать нужный хост через `nix build` или применить через `nixos-rebuild switch`.

### Добавить пакет только для ПК или ноутбука

- System-wide: редактировать `nixos/pc/packages.nix` или `nixos/laptop/packages.nix`.
- User-only: редактировать `home-manager/desktop/pc-packages.nix` или `home-manager/desktop/laptop-packages.nix`.

### Поменять Hyprland/Waybar

- Базовая сессия: `home-manager/hyprland/hyprland-pc.nix` или `home-manager/hyprland/hyprland-laptop.nix`
- Общая логика и скрипты: `home-manager/hyprland/*`
- Статусбар: `waybar-pc.nix` или `waybar-laptop.nix`

### Обновить hardware config

При изменениях железа:

```sh
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Файл нужно положить в соответствующий host directory:

- `nixos/pc/hardware-configuration.nix`
- `nixos/laptop/hardware-configuration.nix`

## Отдельные заметки

MATLAB в этом репозитории запускается так:

```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

Автотестов в репозитории нет. Базовая проверка изменений здесь означает хотя бы успешную сборку целевого `nixosConfiguration`, а для финальной валидации нужен `nixos-rebuild switch` на соответствующем хосте.
