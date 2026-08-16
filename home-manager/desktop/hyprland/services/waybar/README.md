# Waybar

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../../../../README.md)
[![hyprland](https://img.shields.io/badge/hyprland-десктоп-58E1FF?style=for-the-badge)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../../../../../scripts/README.md)
[![screen-shader](https://img.shields.io/badge/screen--shader-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)

Единый бар для обоих хостов: `bar.nix` — база и раскладка, `style.nix` — весь CSS, дальше файл на фичу (индикатор GPU, батарея, подсветка, шейдеры, уведомления). Хост ничего не копирует — только поднимает нужные флаги `rokokol.waybar.*` в `home-<host>.nix`, и бар собирается из этих компонентов

Компонент объявляет **только свои настройки** (`programs.waybar.settings.mainBar."…"` — attrsets сливает модульная система HM). Порядок модулей задаётся в одном месте — `modules-right` в `bar.nix` через `lib.optional`: иначе он зависел бы от порядка `imports`

## Индикаторы и управление

| Модуль                    | ЛКМ                 | ПКМ                        | СКМ                      | Колесо           |
| ------------------------- | ------------------- | -------------------------- | ------------------------ | ---------------- |
| `custom/notifications` 🔔 | лента в rofi        | тумблер DND                | закрыть всё мимо истории | —                |
| `custom/shader`           | rofi-пикер эффектов | сбросить эффекты и яркость | яркость 100% ↔ 50%       | софт-яркость ±5% |
| `backlight`               | —                   | —                          | —                        | подсветка ±1%    |
| `pulseaudio`              | pavucontrol         | —                          | —                        | —                |

`SUPER+Z` — тумблер самого бара

## Тонкости

- **RT-сигналы.** Индикаторы обновляются по `SIGRTMIN+N`: шейдер — `8` (`shader.nix` → `programs.screen-shader.waybar.signal`), уведомления — `9` (`notifications.nix` → `WAYBAR_NOTIF_SIGNAL`). Номер объявлен один раз в Nix и уходит скриптам через env — не задавать второй раз в скриптах. Дефолтное действие RT-сигнала — **убить процесс**, поэтому слать его до готовности waybar нельзя; подробности — в [screen-shader](https://github.com/rokokol/hyprland-screen-shader)
- **CSS один на всех.** Селекторы выключенных модулей (`#custom-gpu`, `#battery`, …) просто не матчатся — стиль не нужно ветвить по хостам
- **Фон несут три панели `.modules-left/.modules-center/.modules-right`**, а не отдельные модули: у модулей фон погашен, свои подложки есть только у `#hardware` (мягкий блок-подмес) и `#tray` — трей носит метку активного воркспейса, тот же тон и тот же радиус 9px
- **Бар всегда тёмный.** waybar спрашивает у портала `org.freedesktop.appearance` и ищет `style-light.css`/`style-dark.css`, а не найдя — берёт `style.css`; кладётся только он, поэтому `toggle-theme.sh` на бар не влияет
- **Новый компонент** = новый файл рядом + опция `rokokol.waybar.<фича>` + место в `modules-right` в `bar.nix` + селектор в списке модулей в `style.nix`
