# Nixvim

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../README.md)
[![programs](https://img.shields.io/badge/programs-программы-7E57C2?style=for-the-badge)](../README.md)

Декларативный Neovim через Nixvim: `default.nix` подключает `inputs.nixvim.homeModules.nixvim`, рядом лежат опции, бинды и пакеты, которые доезжают в окружение самого nixvim (форматтеры, LSP, утилиты). Плагины — в `plugins/`, разложенные по категориям (completion, editor, git, lsp, start, ui), каждая со своим `default.nix`

## Особенности

- цвета приходят из [ddlc.nvim](https://github.com/rokokol/ddlc.nvim): модуль подключается в `settings.nix`, там же `ddlc.nixvim.settings` для настроек прозрачности (её же держит `rokokol.nixvim.transparent`)
- скрытые файлы в поиске переключаются через `<C-h>`
- прокрутка превью в Telescope повешена на `<M-h/j/k/l>`
- media preview определяется по MIME через `file`, а не по расширению
