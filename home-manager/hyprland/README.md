# Hyprland (Home Manager)

Этот каталог содержит конфигурацию Hyprland и сопутствующие настройки.

## Что внутри
- `hyprland.conf` — основной конфиг Hyprland (бинды, правила, переменные).
- `hyprland-*.nix` — хост‑специфичные настройки (PC/ноут).
- `hyprland-packages.nix` — набор пакетов и интеграций, нужных Hyprland.
- `hypridle.nix` — idle‑поведение и таймауты.
- `waybar-*.nix` — конфиги Waybar для разных хостов.
- `systemd.nix` — интеграция с systemd user‑units.
- `cursor.nix` — настройки курсора.
- `scripts/` — вспомогательные скрипты (обои, rofi, синхронизация и т.д.).

## Как вносить изменения
- Бинды и правила: `home-manager/hyprland/hyprland.conf`.
- Пакеты/зависимости: `home-manager/hyprland/hyprland-packages.nix`.
- Хост‑специфичное: `home-manager/hyprland/hyprland-pc.nix` или
  `home-manager/hyprland/hyprland-laptop.nix`.

## Применение
Конфиг применяется через Home Manager, который подключён в `flake.nix`
и `home-manager/home-*.nix`. После правок — обычный `rebuild`.
