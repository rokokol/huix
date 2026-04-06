# Nixvim (Home Manager)

Этот каталог содержит декларативную конфигурацию Neovim через Nixvim.

## Что внутри
- `nixvim.nix` — основной модуль, импортирует остальные части.
- `settings.nix` — базовые настройки Neovim и опции.
- `keymaps.nix` — все пользовательские бинды.
- `plugins/` — конфиги плагинов по категориям (LSP, UI, CMP и т.д.).

## Как вносить изменения
- Настройки ядра: `home-manager/programs/nixvim/settings.nix`.
- Бинды: `home-manager/programs/nixvim/keymaps.nix`.
- Плагины: добавляй/редактируй файлы в `home-manager/programs/nixvim/plugins/`.

## Применение
Nixvim подключён через Home Manager (`home-manager/home-*.nix`).
После правок — `rebuild`.
