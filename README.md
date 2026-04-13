# huix

Конфигурация NixOS и Home Manager для ПК и ноутбука
![Текущее лого](./logo.jpg)


## Что внутри
- `flake.nix` и `flake.lock` — входная точка и зафиксированные зависимости
- `nixos/` — системные модули, хосты, сервисы и локальные шрифты
- `home-manager/` — пользовательские конфиги, Hyprland, программы и desktop-слой
- `logo.jpg` и `wallpaper_*.png` — локальные ассеты

## Быстрый старт

Применить конфиг для ПК

```sh
sudo nixos-rebuild switch --flake .#nixos-pc
```

Применить конфиг для ноутбука

```sh
sudo nixos-rebuild switch --flake .#nixos-laptop
```

Обновить входы flake

```sh
nix flake update
```

В zsh также есть alias `rebuild`

## Структура
- `nixos/configuration-pc.nix` и `nixos/configuration-laptop.nix` — верхнеуровневые хост-конфиги
- `nixos/pc/` и `nixos/laptop/` — хост-специфичные системные модули
- `nixos/services/` — переиспользуемые сервисы
- `nixos/desktop/` — общие desktop-модули
- `nixos/fonts/` — локальные шрифты и модуль подключения
- `home-manager/home-pc.nix` и `home-manager/home-laptop.nix` — entrypoint'ы Home Manager
- `home-manager/desktop/` — desktop-пакеты, тема, mime и user-слой
- `home-manager/hyprland/` — Hyprland-сессия, waybar, hypridle и скрипты
- `home-manager/programs/` — конфиги отдельных программ
- `home-manager/programs/nixvim/` — разложенный по модулям конфиг Neovim
- `home-manager/programs/rofi/` — модуль `rofi`, темы `.rasi` и фоновые SVG

## Комментарии по структуре пакетов
- `home-manager/hyprland/hyprland-packages.nix` содержит только то, что нужно Hyprland-сессии и связанным скриптам
- `home-manager/desktop/common-packages.nix` содержит общий desktop-слой
- `home-manager/desktop/pc-packages.nix` и `home-manager/desktop/laptop-packages.nix` содержат хост-специфичные desktop-пакеты

## Полезное

При изменениях железа можно обновить hardware config так

```sh
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

MATLAB в этом репозитории заводится так

```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```
