# Waybar

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../../../../README.md)
[![hyprland](https://img.shields.io/badge/hyprland-десктоп-58E1FF?style=for-the-badge)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../../../../../scripts/README.md)
[![shaders](https://img.shields.io/badge/shaders-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](../../../../../scripts/shaders/README.md)

Единый бар для обоих хостов: одна база + фичи-модули, каждый в своём файле. Хост ничего не копирует — только объявляет вход через опции `custom.waybar.*`, и бар собирается из нужных компонентов

## Как это собрано

| Файл | Что внутри |
| --- | --- |
| `default.nix` | агрегатор: только `imports` всех компонентов |
| `bar.nix` | база: опция `custom.waybar.enable`, общие модули (workspaces, окно, часы, hardware-группа, звук, раскладка, трей, сеть), раскладка modules-left/center/right и весь CSS |
| `notifications.nix` | `custom/notifications` — индикатор [notify-center](../../../../../scripts/README.md), всегда включён вместе с баром; тянет `mako.nix` |
| `shader.nix` | `custom/shader` — индикатор [полноэкранных шейдеров](../../../../../scripts/shaders/README.md) и софт-яркости |
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

Кто что включает (в `hyprland-pc.nix` / `hyprland-laptop.nix`):

| Хост | Вход |
| --- | --- |
| PC | `nvidia`, `shader`, `temperatureHwmon = hwmon0/temp1_input` |
| Laptop | `shader`, `backlight`, `battery` |

## Индикаторы и управление

| Модуль | ЛКМ | ПКМ | СКМ | Колесо |
| --- | --- | --- | --- | --- |
| `custom/notifications` 🔔 | лента в rofi | тумблер DND | закрыть всё мимо истории | листать ленту в тултипе |
| `custom/shader` | rofi-пикер эффектов | снять эффект | — | софт-яркость ±10% |
| `backlight` | — | — | — | подсветка ±1% |
| `pulseaudio` | pavucontrol | — | — | — |

## Тонкости

- **RT-сигналы.** Индикаторы обновляются по `SIGRTMIN+N`: шейдер — `8` (`shader.nix` → `WAYBAR_SHADER_SIGNAL`), уведомления — `9` (`notifications.nix` → `WAYBAR_NOTIF_SIGNAL`). Номер объявлен один раз в Nix и уходит скриптам через env — не задавать второй раз в скриптах. Дефолтное действие RT-сигнала — **убить процесс**, поэтому слать его до готовности waybar нельзя; подробности — в [shaders/README](../../../../../scripts/shaders/README.md)
- **CSS один на всех.** Селекторы выключенных модулей (`#custom-gpu`, `#battery`, …) просто не матчатся — стиль не нужно ветвить по хостам
- **`cpu`/`memory`/`temperature` живут в `group/hardware`** и стилизуются как один остров; их собственные фоны/рамки погашены отдельным правилом
- **Новый компонент** = новый файл рядом + опция `custom.waybar.<фича>` + место в `modules-right` в `bar.nix` + селектор в списке островов. Не забыть `git add` (hourly-sync берёт только отслеживаемое)

## Применение

Хост импортирует каталог целиком (`./services/waybar` из `hyprland-<host>.nix`) и задаёт вход в `custom.waybar`. Сам waybar стартует через `exec-once` в `hyprland.conf`, `SUPER+Z` — тумблер бара
