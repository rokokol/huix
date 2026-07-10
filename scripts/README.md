<div align="center">

<img src="../assets/SHEF%20OS%20320%20KG.jpg" alt="шеф готовит утилиты" width="300"/>

<em>320kg scripts 💀</em>

</div>

# Скрипты

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![shaders](https://img.shields.io/badge/shaders-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](shaders/README.md)

Рукописные shell-обёртки, рассчитанные на путь `$HUIX/scripts`. Часть из них дёргается биндами Hyprland, часть — systemd-юнитами и Nix-обёртками из [программ](../home-manager/programs/README.md)

## Что внутри

| Скрипт | Что делает |
| --- | --- |
| `sync.sh` | авто-синк конфига: `git pull --rebase --autostash` → `add` → `commit` → `push`, ежечасно по таймеру |
| `toggle_theme.sh` | переключение light/dark: dconf `color-scheme`+`gtk-theme`, тема rofi, выбор в state-файле |
| `screen-shader.sh` | менеджер полноэкранных шейдеров и софт-яркости, см. [shaders/README.md](shaders/README.md) |
| `notify-center.sh` | центр уведомлений поверх mako: режим «не беспокоить», копирование текста уведомлений, очистка истории, JSON-статус для waybar |
| `hyprlock-quote.sh` | реплики Моники для DDLC-локскрина: экспоненциальные паузы между сменами, глитч-кадр с вероятностью 1/3 |
| `hyprlock-stickers.sh` | аниматор стикеров на локскрине: блуждание с паузами по низу экрана, гауссовские прыжки; двойной буфер, чтобы не фризить hyprlock |
| `random_wallpaper.sh` | рандомные обои для Hyprland (выборка по нормальному распределению) |
| `colorpicker.sh` | пипетка через `hyprpicker`, копирует HEX/RGB и шлёт превью в уведомление |
| `pin-screen.sh` | закрепить выделенную область экрана поверх остальных окон |
| `zoom.sh` | живая лупа: зум экрана вокруг курсора через `cursor:zoom_factor` (ALT+WIN+колесо) |
| `rofi-clipboard.sh` | история буфера через `cliphist` в rofi с превью |
| `rofi-libre.sh` | перевод выделенного через LibreTranslate в rofi |
| `rofi-notify.sh` | лента уведомлений в rofi: клик копирует текст, очистить всё, тумблер DND |
| `rofi-shader.sh` | пикер эффектов как rofi script-modi |
| `rofi_wooordhunt.sh` | словарь wooordhunt в rofi |
| `virtual-cam.sh` | виртуальная камера на повторе через `v4l2loopback` |
| `virtual-mic.sh` | виртуальный микрофон через PipeWire |
| `alarm.sh` | будильник: `rtcwake` на пробуждение + проигрывание звука, чисто гасится по `Ctrl+C` |
| `normalize-nix-entry-style.sh` | массовая нормализация заголовков Nix-модулей |
| `shaders/` | фрагментные шейдеры (`*.frag`), один файл = один эффект, см. [shaders/README.md](shaders/README.md) |

## Тонкости

- **`sync.sh` коммитит и пушит всё застейдженное** ежечасно — не оставляй в дереве то, чего не хочешь видеть в истории. При этом он делает `add -u` (только отслеживаемые), так что новый файл, забытый без `git add`, тихо не уедет в upstream
- пути не хардкодь — бери `$HUIX` в скриптах и `huixDir` в Nix
- многие скрипты завязаны на рантайм-state в `~/.local/state/huix/` (тема, шейдер) — он переживает логаут/ребут и восстанавливается на reload Hyprland

## Применение

Скрипты подключаются либо биндами в `home-manager/desktop/hyprland/hyprland.conf`, либо Nix-обёртками (`writeShellApplication`), которые кладут зависимости в PATH
