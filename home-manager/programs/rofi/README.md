# Rofi

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
- `home-manager/hyprland/scripts/toggle_theme.sh` переключает `active.rasi` между light и dark

## Где что менять
- Nix-слой и раскладка файлов — `home-manager/programs/rofi/default.nix`
- светлая тема — `home-manager/programs/rofi/theme-light.rasi`
- тёмная тема — `home-manager/programs/rofi/theme-dark.rasi`
- фоновые SVG — `home-manager/programs/rofi/assets/`

## Применение

Модуль подключен через `home-manager/home-pc.nix` и `home-manager/home-laptop.nix`

После правок достаточно обычного `rebuild`
