# Nixvim (Home Manager)

Этот каталог содержит декларативную конфигурацию Neovim через Nixvim

## Что внутри
- `nixvim.nix` — основной модуль, импортирует остальные части
- `settings.nix` — базовые настройки Neovim и опции
- `keymaps.nix` — все пользовательские бинды
- `plugins/` — конфиги плагинов по категориям (LSP, UI, CMP и т.д.)

## Плагины
- `plugins/default.nix` — единая точка импорта всех модулей плагинов; в корне `plugins/` больше не лежат отдельные конфиги плагинов
- `plugins/completion/` — completion-плагины (`cmp`, `luasnip`)
- `plugins/editor/` — редакторские плагины (`neo-tree`, `telescope`, `treesitter`, `which-key`, `toggleterm`, `mini`)
- `plugins/git/` — git-плагины (`gitsigns`, `lazygit`)
- `plugins/lsp/` — LSP, диагностика и форматирование
- `plugins/start/` — стартовые плагины и логика старта (`alpha`, `persistence`, `project-nvim`)
- `plugins/ui/` — UI и работа с изображениями (`bufferline`, `lualine`, `web-devicons`, `image`)

### Telescope
- Telescope helper'ы вынесены в `home-manager/programs/nixvim/plugins/editor/telescope-helpers.nix`
- В `ff`, `fa`, `fg` и поиске файлов внутри `projects` скрытые файлы переключаются через `<C-h>`
- Media preview в Telescope определяется по MIME через `file`, а не по расширению

## Как вносить изменения
- Настройки ядра: `home-manager/programs/nixvim/settings.nix`
- Бинды: `home-manager/programs/nixvim/keymaps.nix`
- Плагины: добавляй/редактируй файлы в `home-manager/programs/nixvim/plugins/`

## Применение
Nixvim подключён через Home Manager (`home-manager/home-*.nix`)
Тажке скачан `which-key`, чтобы помочь разобраться с моими кастомными шорткатами
После правок — `rebuild`
