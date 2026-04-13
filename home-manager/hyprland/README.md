# Hyprland

Этот каталог содержит конфигурацию Hyprland-сессии и все, что живет рядом с ней

## Что внутри
- `hyprland.conf` — основной конфиг Hyprland с биндами, правилами и переменными
- `hyprland-pc.nix` и `hyprland-laptop.nix` — хост-специфичные настройки
- `hyprland-packages.nix` — пакеты и интеграции, которые реально нужны сессии
- `hypridle.nix` — idle-поведение, lock и действия до и после сна
- `waybar-pc.nix` и `waybar-laptop.nix` — панели для разных хостов
- `systemd.nix` — user units и timer'ы, связанные с сессией
- `cursor.nix` — курсор и его интеграция в GTK и Wayland
- `scripts/` — вспомогательные скрипты для скриншотов, `rofi`, синка и обоев

## Скрипты
- `scripts/colorpicker.sh` — пипетка с копированием цвета
- `scripts/pin-screen.sh` — закрепление участка экрана как окна-картинки
- `scripts/random_wallpaper.sh` — сборка коллажа и установка случайных обоев через `awww`
- `scripts/rofi-clipboard.sh` — просмотр clipboard с превью картинок и удалением записей
- `scripts/rofi_wooordhunt.sh` — быстрый поиск перевода и значений слов
- `scripts/sync.sh` — `git pull` / commit / push с уведомлениями
- `scripts/toggle_theme.sh` — переключение light и dark для `rofi` и связанного desktop-слоя

## Где что менять
- Бинды и window rules — `home-manager/hyprland/hyprland.conf`
- Пакеты и зависимости — `home-manager/hyprland/hyprland-packages.nix`
- Idle и lock — `home-manager/hyprland/hypridle.nix`
- Waybar — `home-manager/hyprland/waybar-pc.nix` или `home-manager/hyprland/waybar-laptop.nix`
- Скрипты — `home-manager/hyprland/scripts/`

## Применение

Конфиг подключается через `home-manager/home-pc.nix` и `home-manager/home-laptop.nix`

После правок достаточно обычного `rebuild`
