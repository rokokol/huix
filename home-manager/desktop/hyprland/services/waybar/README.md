# Waybar

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../../../../README.md)
[![hyprland](https://img.shields.io/badge/hyprland-десктоп-58E1FF?style=for-the-badge)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../../../../../scripts/README.md)
[![screen-shader](https://img.shields.io/badge/screen--shader-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)

Единый бар для обоих хостов: одна база + фичи-модули, каждый в своём файле. Хост ничего не копирует — только объявляет вход через опции `custom.waybar.*`, и бар собирается из нужных компонентов

## Как это собрано

| Файл | Что внутри |
| --- | --- |
| `default.nix` | агрегатор: только `imports` всех компонентов |
| `bar.nix` | база: опция `custom.waybar.enable`, общие модули (workspaces, окно, часы, hardware-группа, звук, раскладка, трей, сеть), раскладка modules-left/center/right и раскладка CSS-листов по `~/.config/waybar` |
| `style.nix` | сам CSS: одна вёрстка + два набора цветов (`light`/`dark`) |
| `notifications.nix` | `custom/notifications` — индикатор [notify-center](../../../../../scripts/README.md), всегда включён вместе с баром; тянет `mako.nix` |
| `shader.nix` | `custom/shader` — индикатор [полноэкранных шейдеров](https://github.com/rokokol/hyprland-screen-shader) и софт-яркости: только номер сигнала и имя бара, всё остальное приходит из флейка |
| `nvidia.nix` | `custom/gpu` — загрузка/память/температура GPU через `nvidia-smi` |
| `backlight.nix` | аппаратная подсветка, колесо → `brightnessctl` |
| `battery.nix` | батарея |

Компоненты объявляют **только свои настройки** (`programs.waybar.settings.mainBar."..."` — attrsets сливает модульная система HM). Порядок модулей в баре задаётся в одном месте — `modules-right` в `bar.nix` через `lib.optional`: иначе он зависел бы от порядка `imports`

## Вход (опции `custom.waybar.*`)

| Опция | Тип | Что даёт |
| --- | --- | --- |
| `enable` | bool | сам бар и уведомления |
| `shader` | bool | индикатор шейдеров/софт-яркости |
| `nvidia` | bool | индикатор NVIDIA GPU |
| `backlight` | bool | индикатор аппаратной подсветки |
| `battery` | bool | индикатор батареи |
| `temperatureHwmon` | null или str | `hwmon-path` для модуля temperature; `null` — автовыбор waybar |

Кто что включает (в `home-pc.nix` / `home-laptop.nix`):

| Хост | Вход |
| --- | --- |
| PC | `nvidia`, `shader`, `temperatureHwmon = hwmon0/temp1_input` |
| Laptop | `shader`, `backlight`, `battery` |

## Индикаторы и управление

| Модуль | ЛКМ | ПКМ | СКМ | Колесо |
| --- | --- | --- | --- | --- |
| `custom/notifications` 🔔 | лента в rofi | тумблер DND | закрыть всё мимо истории | — |
| `custom/shader` | rofi-пикер эффектов | снять эффект | — | софт-яркость ±10% |
| `backlight` | — | — | — | подсветка ±1% |
| `pulseaudio` | pavucontrol | — | — | — |

## Тонкости

- **RT-сигналы.** Индикаторы обновляются по `SIGRTMIN+N`: шейдер — `8` (`shader.nix` → `programs.screen-shader.waybar.signal`), уведомления — `9` (`notifications.nix` → `WAYBAR_NOTIF_SIGNAL`). Номер объявлен один раз в Nix и уходит скриптам через env — не задавать второй раз в скриптах. Дефолтное действие RT-сигнала — **убить процесс**, поэтому слать его до готовности waybar нельзя; подробности — в [screen-shader](https://github.com/rokokol/hyprland-screen-shader)
- **CSS один на всех.** Селекторы выключенных модулей (`#custom-gpu`, `#battery`, …) просто не матчатся — стиль не нужно ветвить по хостам
- **Фон несут три панели `.modules-left/.modules-center/.modules-right`**, а не отдельные модули: у модулей фон погашен, свои подложки есть только у `#hardware` и `#tray` — они читаются как блоки внутри правой панели
- **Тема переключается сама.** waybar спрашивает у портала `org.freedesktop.appearance` и берёт `style-light.css` или `style-dark.css`, а на смену схемы перечитывает лист **вживую, без рестарта** — поэтому [toggle-theme.sh](../../../../../scripts/README.md) ничего про бар не знает. Работает только пока waybar стартует **без `-s`** (`exec-once = waybar` в `hyprland.conf`): аргумент отключает выбор по теме. `style.css` кладётся тем же тёмным набором — это фолбэк на сессию без портала
- **Стеклянные оба набора, но альфа разная.** Слой waybar блюрится (`layerrule = blur on` в `hyprland.conf`); тёмная подложка держит 0.62, светлая — 0.82. Разница не вкусовая: бледный фон подмешивает в себя обои, и заметно ниже над тёмными обоями он сереет, перестаёт читаться светлым и роняет контраст тёмного текста
- **Новый компонент** = новый файл рядом + опция `custom.waybar.<фича>` + место в `modules-right` в `bar.nix` + селектор в списке модулей в `style.nix`. Не забыть `git add` (sync берёт только отслеживаемое)

## Применение

Каталог целиком импортирует `hyprland.nix`, а вход `custom.waybar` задаёт `home-<host>.nix`. Сам waybar стартует через `exec-once` в `hyprland.conf`, `SUPER+Z` — тумблер бара
