# Rofi

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../README.md)
[![programs](https://img.shields.io/badge/programs-программы-7E57C2?style=for-the-badge)](../README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](../nixvim/README.md)

Этот каталог содержит конфиг `rofi`, разложенный по отдельным файлам

## Что внутри
- `default.nix` — Home Manager модуль и раскладка файлов в `~/.config/rofi`
- `theme-light.rasi` — светлая тема
- `theme-dark.rasi` — тёмная тема
- `assets/` — фоновые SVG для тем

## Как это устроено
- Home Manager кладёт базовый конфиг и обе темы в `~/.config/rofi`
- `config.rasi` подключает `base.rasi` и активную тему
- активная тема выбирается через `themes/active.rasi`
- если `active.rasi` ещё не существует, модуль создаёт его как ссылку на `light.rasi`
- `scripts/toggle-theme.sh` переключает `active.rasi` между light и dark

## Где что менять
- Nix-слой и раскладка файлов — `home-manager/programs/rofi/default.nix`
- светлая тема — `home-manager/programs/rofi/theme-light.rasi`
- тёмная тема — `home-manager/programs/rofi/theme-dark.rasi`
- фоновые SVG — `home-manager/programs/rofi/assets/`

## Применение

Модуль подключен через `home-manager/home-pc.nix` и `home-manager/home-laptop.nix`