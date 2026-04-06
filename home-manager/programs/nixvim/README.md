# Nixvim (Home Manager)

Этот каталог содержит декларативную конфигурацию Neovim через Nixvim.

## Что внутри
- `nixvim.nix` — основной модуль, импортирует остальные части.
- `settings.nix` — базовые настройки Neovim и опции.
- `keymaps.nix` — все пользовательские бинды.
- `plugins/` — конфиги плагинов по категориям (LSP, UI, CMP и т.д.).

## Плагины
- `plugins/default.nix` — единая точка импорта всех модулей плагинов.
- `plugins/alpha.nix` — стартовый экран.
- `plugins/cmp.nix` — автодополнение.
- `plugins/completion/` — completion-плагины (`cmp`, `luasnip`).
- `plugins/editor/` — редакторские плагины (`neo-tree`, `telescope`, `treesitter`, `which-key`, `toggleterm`, `mini`, `persistence`).
- `plugins/git/` — git-плагины (`gitsigns`, `lazygit`).
- `plugins/lsp/` — LSP, диагностика и форматирование.
- `plugins/ui/` — UI и работа с изображениями (`bufferline`, `lualine`, `web-devicons`, `image`).

## Как вносить изменения
- Настройки ядра: `home-manager/programs/nixvim/settings.nix`.
- Бинды: `home-manager/programs/nixvim/keymaps.nix`.
- Плагины: добавляй/редактируй файлы в `home-manager/programs/nixvim/plugins/`.

## Применение
Nixvim подключён через Home Manager (`home-manager/home-*.nix`).
После правок — `sudo nixos-rebuild switch --flake .#nixos-pc` или `sudo nixos-rebuild switch --flake .#nixos-laptop`.
