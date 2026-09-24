# Waybar

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../../../../README.md)
[![hyprland](https://img.shields.io/badge/hyprland-десктоп-58E1FF?style=for-the-badge)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../../../../../scripts/README.md)
[![screen-shader](https://img.shields.io/badge/screen--shader-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)

Единый бар для обоих хостов: `bar.nix` — база и раскладка, `style.nix` — весь CSS, дальше файл на фичу (индикатор GPU, батарея, подсветка, шейдеры, уведомления, кнопки лаунчера и клавиатуры, память со swap). Хост ничего не копирует — только поднимает нужные флаги `rokokol.waybar.*` в `home-<host>.nix`, и бар собирается из этих компонентов

Компонент объявляет **только свои настройки** (`programs.waybar.settings.mainBar."…"` — attrsets сливает модульная система HM). Порядок модулей задаётся в одном месте — `modules-left` и `modules-right` в `bar.nix` через `lib.optional`: иначе он зависел бы от порядка `imports`

## Индикаторы и управление

| Модуль                    | ЛКМ                             | ПКМ                        | СКМ                      | Колесо           |
| ------------------------- | ------------------------------- | -------------------------- | ------------------------ | ---------------- |
| `custom/launcher` 🐣      | меню приложений (`menuCommand`) | —                          | —                        | —                |
| `custom/virt-keyboard` ⌨️ | показать/спрятать wvkbd         | —                          | —                        | —                |
| `custom/notifications` 🔔 | лента в rofi                    | тумблер DND                | закрыть всё мимо истории | —                |
| `custom/shader`           | rofi-пикер эффектов             | сбросить эффекты и яркость | яркость 100% ↔ 50%       | софт-яркость ±5% |
| `backlight`               | —                               | —                          | —                        | подсветка ±1%    |
| `pulseaudio`              | pavucontrol                     | —                          | —                        | —                |

`SUPER+Z` — тумблер самого бара

Ноутбучные компоненты: 🐣 и ⌨️ живут слева в одной группе `group/buttons` с общей подложкой, чтобы палец видел, куда жать; ⌨️ появляется только в tablet-режиме и тем самым служит его индикатором — `tablet-mode.sh` дёргает бар сигналом при смене режима; процесс бара называется `.waybar-wrapped`, так что `pkill` ищет подстроку, а не точное имя. `custom/memory` заменяет штатный `memory`, когда поднят `rokokol.waybar.swap`: `memory-status.sh` читает `/proc/meminfo` и пишет `ram/swapGb`, краснея от `swapWarnMb` мегабайт занятого swap — у штатного модуля порог только по проценту RAM. `programs.screen-shader.waybar.idleIcon` в `home-laptop.nix` оставляет 🌈 в индикаторе шейдеров, когда ничего не включено — иначе модуль прячется, и пальцу нечего нажать

## Тонкости

- **RT-сигналы.** Индикаторы обновляются по `SIGRTMIN+N`: шейдер — `8` (`shader.nix` → `programs.screen-shader.waybar.signal`), уведомления — `9` (`notifications.nix` → `WAYBAR_NOTIF_SIGNAL`), кнопка клавиатуры — `10` (`virt-keyboard.nix` → `HUIX_TABLET_SIGNAL`). Номер объявлен один раз в Nix и уходит скриптам через env — не задавать второй раз в скриптах. Дефолтное действие RT-сигнала — **убить процесс**, поэтому слать его до готовности waybar нельзя; подробности — в [screen-shader](https://github.com/rokokol/hyprland-screen-shader)
- **Раскладка — с одной клавиатуры.** `hyprland/language` без `keyboard-name` принимает `activelayout` от любой клавиатуры, а wvkbd — тоже клавиатура с раскладкой по имени "wvkbd", которой нет в реестре xkb: с его стартом подпись пустела до следующего переключения на физической. `rokokol.waybar.layoutKeyboard` в `home-laptop.nix` называет физическую клавиатуру так, как её печатает `hyprctl devices`, и модуль слушает только её
- **CSS один на всех.** Селекторы выключенных модулей (`#custom-gpu`, `#battery`, …) просто не матчатся — стиль не нужно ветвить по хостам
- **Фон несут три панели `.modules-left/.modules-center/.modules-right`**, а не отдельные модули: у модулей фон погашен, свои подложки есть только у `#hardware` (мягкий блок-подмес), `#buttons` (та же подложка под кнопками) и `#tray` — трей носит метку активного воркспейса, тот же тон и тот же радиус 9px
- **Бар всегда тёмный.** waybar спрашивает у портала `org.freedesktop.appearance` и ищет `style-light.css`/`style-dark.css`, а не найдя — берёт `style.css`; кладётся только он, поэтому `toggle-theme.sh` на бар не влияет
- **Новый компонент** = новый файл рядом + опция `rokokol.waybar.<фича>` + место в `modules-left`/`modules-right` в `bar.nix` + селектор в списке модулей в `style.nix`
