# Rofi (Home Manager)

Этот каталог содержит конфиг `rofi`, разложенный по файлам

## Что внутри
- `default.nix` — Home Manager модуль и раскладка файлов в `~/.config/rofi`
- `theme-light.rasi` — светлая тема
- `theme-dark.rasi` — тёмная тема
- `assets/` — фоновые SVG для тем

## Логика переключения
- Home Manager кладёт обе темы в `~/.config/rofi/themes/`
- активная тема выбирается через `themes/active.rasi`
- `home-manager/hyprland/scripts/toggle_theme.sh` переключает GTK-тему и обновляет `active.rasi`
