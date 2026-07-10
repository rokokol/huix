# Hyprland

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../../../scripts/README.md)
[![shaders](https://img.shields.io/badge/shaders-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](../../../scripts/shaders/README.md)
[![rofi](https://img.shields.io/badge/rofi-лаунчер-EE2A7B?style=for-the-badge)](../../programs/rofi/README.md)

Мой Wayland-десктоп на Hyprland. Слой `dwindle`-тайлинга, обвязка из waybar/mako/hypridle/обоев и куча биндов, заточенных под HJKL, скриншоты с OCR, перевод и словарь прямо из rofi, живую лупу, полноэкранные шейдеры и рантайм-переключение темы

## Как это собрано

Конфиг намеренно **гибридный**: декларативная часть в Nix + один большой императивный `hyprland.conf`, который Nix просто `source`-ит

| Файл | Что внутри |
| --- | --- |
| `hyprland.conf` | весь общий конфиг: autostart, env, look&feel, биндинги, window/layer-rules. Правится руками, не через Nix-опции |
| `hyprland.nix` | единый Nix-модуль: опции `custom.hyprland.*` (масштаб монитора, XKB-опции, natural scroll, обои — статичные или коллаж); вход задают `home-pc.nix` / `home-laptop.nix` |
| `services/hyprland-packages.nix` | общий пакетный набор (kitty, awww, hypridle, grim/slurp/satty, tesseract rus+eng, cliphist…), `source` главного конфига, конфиг swayimg |
| `services/waybar/` | единый бар: база + файл на фичу, хост включает нужное опциями — см. [waybar/README](services/waybar/README.md) |
| `services/mako.nix` | уведомления, цвета по `urgency`, меню по правому клику в rofi |
| `services/hypridle.nix` | лок по таймауту 90 мин + перед сном, `hyprlock` |
| `services/hyprlock.nix` | DDLC-локскрин: генерируемый из SVG анимированный фон (дрейф горошка через reload+кроссфейд), цитаты Моники, сердечки вместо точек пароля |
| `services/wallpaper_collager.nix` | systemd-user таймер: коллаж обоев через `random_wallpaper.sh` |

> **Почему `source`, а не нативные `settings`.** Главный конфиг один на оба хоста и редактируется быстрее как текст; per-host через `hyprland.conf` `source = …` подтягивается из `${huixDir}`, а различия (монитор, раскладка, бар) задаются в `*-pc.nix`/`*-laptop.nix`. Пути не хардкодятся — везде `$HUIX` / `huixDir`

## Стек компонентов

- **`awww`** вместо `hyprpaper` — демон обоев, на PC обои генерятся коллажем по нормальному распределению (`random_wallpaper.sh`)
- **`mako`** вместо `dunst`/`swaync` — минималистичные уведомления с цветовыми темами по urgency
- **`swayosd`** — OSD громкости/яркости/раскладки (systemd-user сервис)
- **`rofi`** как швейцарский нож — не только launcher, но и буфер (`cliphist`), эмодзи/математика/каомодзи (`rofimoji`), словарь wooordhunt, перевод через LibreTranslate, пикер шейдеров
- **`tesseract` (rus+eng)** — OCR со скриншота прямо в буфер
- **`satty`** — редактор скриншотов
- **`playerctld`** — управление медиа через единый плеер
- **`hyprlock` + `hypridle`** — лок и автоблокировка
- **скриншоты — `grim`/`slurp`**, обёрнуто в `$getScreen` (рамка выделения + задержка)

## Хоткеи

Мод — `SUPER` (`$mainMod`), "скриншотный" мод — `SUPER ALT` (`$mainScreenMod`)

### Окна и фокус

| Бинд | Действие |
| --- | --- |
| `SUPER + Q` | терминал (kitty) |
| `SUPER + W` | launcher (rofi drun) |
| `SUPER + E` | файловый менеджер (thunar) |
| `SUPER + C` | закрыть окно |
| `SUPER + V` | toggle floating |
| `SUPER + F` | фулскрин (полный), `SUPER+P` — pseudo, `SUPER+T` — togglesplit |
| `SUPER + H/J/K/L` | фокус ←↓↑→ (и стрелки) |
| `SUPER SHIFT + H/J/K/L` | двигать окно ←↓↑→ |
| `SUPER CTRL + H/J/K/L` | точное смещение floating-окна на 80px |
| `SUPER ALT + H/J/K/L` | resize активного окна |
| `SUPER + ЛКМ/ПКМ` | перетащить / ресайз окна мышью |

### Воркспейсы

| Бинд | Действие |
| --- | --- |
| `SUPER + 1…9` | на воркспейс N |
| `SUPER SHIFT + 1…0` | перенести окно на воркспейс N |
| `SUPER + S` / `SUPER SHIFT + S` | scratchpad `magic` / закинуть туда окно |
| `SUPER + колесо` | следующий/предыдущий воркспейс по кругу (4 «таба») |
| `SUPER SHIFT + колесо` | перенести окно на соседний воркспейс по кругу |

### Скриншоты, OCR, экран

| Бинд | Действие |
| --- | --- |
| `SUPER ALT + S` | скриншот области → редактор satty |
| `SUPER ALT + C` | скриншот области → буфер |
| `SUPER ALT + M` | скриншот всего монитора → буфер |
| `SUPER ALT + T/R/E` | OCR области (rus+eng / rus / eng) → буфер |
| `SUPER ALT + A` | закрепить область экрана поверх окон (`pin-screen.sh`) |
| `SUPER ALT + P` | пипетка цвета (`colorpicker.sh` / hyprpicker) |
| `SUPER ALT + колесо` | живая лупа вокруг курсора (`zoom.sh`), `SUPER ALT + Backspace` — сброс |

### Утилиты и тема

| Бинд | Действие |
| --- | --- |
| `SUPER + A` | переключить light/dark тему (`toggle_theme.sh`) |
| `SUPER + B` | история буфера (cliphist в rofi) |
| `SUPER SHIFT + B` | эмодзи/математика/символы/каомодзи (rofimoji) |
| `SUPER + Y` | словарь wooordhunt в rofi |
| `SUPER + U` | перевод ru↔en через LibreTranslate |
| `SUPER + G` | toggle grayscale-шейдер, `SUPER SHIFT + G` — пикер шейдеров |
| `SUPER CTRL + [ / ]` | софт-яркость через шейдер вниз/вверх, `Backspace` — сброс |
| `SUPER + Z` | toggle waybar |
| `SUPER + F12` | лок сессии |
| медиа/яркость | `XF86Audio*` / `XF86MonBrightness*` → swayosd + playerctl |

## Фиксы и тонкости

Накопленные костыли под конкретные баги — то, чего нет в дефолтном конфиге:

- **Unreal Editor (`ue4-drag-empty-fix`)** — UE4/UnrealEditor плодит невидимые drag-окна с пустым `title`; правило `no_initial_focus + no_focus` для класса `^(UE4Editor|UnrealEditor)$` с пустым тайтлом, чтобы фокус не угонялся
- **XWayland drag-фикс (`fix-xwayland-drags`)** — пустые xwayland-окна перетаскивания (`class==""`, `title==""`) получают `no_focus`, иначе ломается DnD
- **`xwayland.force_zero_scaling = true`** — чтобы xwayland-приложения не были мыльными на дробном скейле
- **`suppress-maximize-events`** — глобально гасим запросы максимизации от всех приложений
- **`hyprland-run`** — окно лаунчера фиксируется внизу монитора (`move = 20 monitor_h-120`, `float`)
- **планшет Gaomon S630** прибит к выходу `DP-1` (PC), иначе мапится на оба монитора
- **зум** — `cursor:zoom_factor` живой
- **тема свет/тьма — рантайм, не декларатив** — `SUPER+A` → `toggle_theme.sh` флипает dconf и пишет выбор в `~/.local/state/huix/theme`; на reload восстанавливается через `exec = toggle_theme.sh --sync`. Подробности и грабли — в [scripts/README](../../../scripts/README.md)
- **шейдеры/софт-яркость** — единственный слот `decoration:screen_shader` менеджит `screen-shader.sh`; состояние в state, восстанавливается через `exec = screen-shader.sh restore`. Индикатор в waybar обновляется по RT-сигналу `SIGRTMIN+8` (`shaderSignal`); слать его до готовности waybar нельзя — RT-сигнал по умолчанию убивает процесс, поэтому `restore` сигнал подавляет
- **swayimg** — навигация и копирование в буфер забиндены и на латинице, и на кириллице (`c/с`, `h/р`, …), чтобы работало при любой раскладке
- **hyprlock: фон — картинка, не скриншот** — иначе эффект от шейдеров применяется дважды
- **hyprlock-guard + `allow_session_lock_restore`** — кроссфейд фона обязан быть короче `reload_time` (перекрытие роняет hyprlock по SIGSEGV), а на случай любого краша локера сторожок перезапускает его — без него сессия остаётся залоченной и спасает только tty

## Применение

Подключается из `home-manager/home-<host>.nix` через `desktop/user.nix`. Общий `hyprland.conf` `source`-ится из Nix-обвязки, per-host различия — опции `custom.hyprland.*` и `custom.waybar.*`, выставляемые в `home-<host>.nix`. Бинды дёргают скрипты из [`$HUIX/scripts`](../../../scripts/README.md)
