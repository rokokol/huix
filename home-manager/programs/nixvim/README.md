# Nixvim

Этот каталог содержит декларативную конфигурацию Neovim через Nixvim

## Что внутри
- `default.nix` — основной модуль и точка входа, подключает `inputs.nixvim.homeModules.nixvim`
- `settings.nix` — базовые опции Neovim
- `keymaps.nix` — все пользовательские бинды
- `packages.nix` — сторонние пакеты, которые добавляются в окружение nixvim (форматтеры, LSP, утилиты)
- `plugins/` — плагины, разложенные по категориям

## Структура плагинов
- `plugins/default.nix` — единая точка импорта всех категорий
- `plugins/completion/` — completion и snippets
- `plugins/editor/` — редакторские плагины, `neo-tree`, `telescope`, `treesitter`, `toggleterm`, `mini`, `which-key`
- `plugins/git/` — git-интеграции
- `plugins/lsp/` — LSP, diagnostics и форматирование
- `plugins/start/` — стартовый экран, project logic и persistence
- `plugins/ui/` — statusline, tabs, icons и работа с изображениями

## Особенности
- helper'ы Telescope лежат в `plugins/editor/telescope-helpers.nix`
- скрытые файлы в поиске переключаются через `<C-h>`
- прокрутка превью в Telescope повешена на `<M-h/j/k/l>`
- media preview определяется по MIME через `file`, а не по расширению

## Где что менять
- ядро и опции — `home-manager/programs/nixvim/settings.nix`
- бинды — `home-manager/programs/nixvim/keymaps.nix`
- плагины — `home-manager/programs/nixvim/plugins/`

## Применение

Модуль подключен через `home-manager/home-pc.nix` и `home-manager/home-laptop.nix`

После правок достаточно обычного `rebuild`
