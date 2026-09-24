# Hyprland

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../../../scripts/README.md)
[![screen-shader](https://img.shields.io/badge/screen--shader-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)
[![rofi-wooordhunt](https://img.shields.io/badge/rofi--wooordhunt-словарь-F4A100?style=for-the-badge)](https://github.com/rokokol/rofi-wooordhunt)

Мой Wayland-десктоп на Hyprland. Слой `dwindle`-тайлинга, обвязка из waybar/mako/hypridle/обоев и куча биндов, заточенных под vim-клавиши, скриншоты с OCR, перевод и словарь прямо из rofi, живую лупу, полноэкранные шейдеры и рантайм-переключение темы

## Как это собрано

Hyprland здесь — main-ветка из её флейка, а не релиз из nixpkgs, потому что конфиг на Lua живёт только там (релизная серия hyprlang-конфиг потеряла с 0.57). Плагины hyprgrass и hyprbars приходят из своих флейков и через `follows` собираются ровно против той же ревизии; все четыре пакета подменяют nixpkgs-имена оверлеем `overlay-hyprland` во `flake.nix`, так что `programs.hyprland`, HM-модуль, портал и PATH скриптов берут их без строчки на каждого. Почему вход Hyprland не `follows`-ит общий nixpkgs — в [DEVIATIONS.md](../../../DEVIATIONS.md)

Конфиг намеренно **гибридный**: декларативная часть в Nix + один большой императивный `hyprland.lua`, который сгенерированный HM-файл подгружает через `dofile` из живого чекаута

`hyprland.lua` держит весь общий конфиг — autostart, env, look&feel, все бинды, window/layer-rules — и правится руками. `hyprland.nix` — единственный Nix-модуль слоя: объявляет опции `rokokol.hyprland.*` (масштаб монитора, XKB, natural scroll, обои, команда меню) и импортирует `services/`, где лежит файл на компонент: пакетный набор десктопа, [waybar](services/waybar/README.md), mako, hypridle, тумблер крышки, tablet-режим, заголовки окон, тач-жесты, коллажер обоев и швы к вынесенным флейкам. Каждый атрибут `settings` в этих модулях — один вызов `hl.<имя>(...)` в сгенерированном файле, и он выполняется раньше `dofile`, поэтому `hyprland.lua` не знает ни цветов, ни хоста

Из Nix в живой файл ведёт одна глобальная таблица `HUIX`: `HUIX.menu` — команда меню приложений (`rokokol.hyprland.menuCommand`, её же читают кнопка в waybar и жест), `HUIX.scripts` — каталог скриптов

> [!NOTE]
> Почему `dofile`, а не нативные `settings`. Главный конфиг один на оба хоста и редактируется быстрее как текст: правка применяется по `hyprctl reload`, без `rebuild`. В Nix уходит только то, что различается по хостам или приходит из палитры

## Стек компонентов

Где выбор неочевиден:

- **`awww`** вместо `hyprpaper` — демон обоев, на ПК картинка генерится коллажем по нормальному распределению (`random-wallpaper.sh`)
- **`mako`** вместо `dunst`/`swaync` — минималистичные уведомления
- **`rofi`** — моя любимая програма. Лаунчер, буфер (`cliphist`), эмодзи (`rofimoji`), словарь [wooordhunt](https://github.com/rokokol/rofi-wooordhunt), перевод через LibreTranslate, пикер шейдеров, меню питания
- **`tesseract` (rus+eng)** для копирования текста с экрана
- **`swayosd`** — OSD громкости/яркости/раскладки отдельным systemd-user сервисом

## Хоткеи

Мод — `SUPER`, "скриншотный" мод — `SUPER ALT`; в Lua-конфиге клавиши пишутся как `"SUPER + ALT + S"`

### Окна и фокус

| Бинд                    | Действие                                                       |
| ----------------------- | -------------------------------------------------------------- |
| `SUPER + Q`             | терминал (kitty)                                               |
| `SUPER + W`             | launcher (rofi drun)                                           |
| `SUPER + E`             | файловый менеджер (thunar)                                     |
| `SUPER + C`             | закрыть окно                                                   |
| `SUPER + V`             | toggle floating                                                |
| `SUPER + F`             | фулскрин (полный), `SUPER+P` — pseudo, `SUPER+T` — togglesplit |
| `SUPER + H/J/K/L`       | фокус ←↓↑→ (и стрелки)                                         |
| `SUPER SHIFT + H/J/K/L` | двигать окно ←↓↑→                                              |
| `SUPER CTRL + H/J/K/L`  | точное смещение floating-окна на 80px                          |
| `SUPER ALT + H/J/K/L`   | resize активного окна                                          |
| `SUPER + ЛКМ/ПКМ`       | перетащить / ресайз окна мышью                                 |

### Воркспейсы

| Бинд                            | Действие                                           |
| ------------------------------- | -------------------------------------------------- |
| `SUPER + 1…9`                   | на воркспейс N                                     |
| `SUPER SHIFT + 1…0`             | перенести окно на воркспейс N                      |
| `SUPER + S` / `SUPER SHIFT + S` | scratchpad `magic` / закинуть туда окно            |
| `SUPER + колесо`                | следующий/предыдущий воркспейс по кругу (4 "таба") |
| `SUPER SHIFT + колесо`          | перенести окно на соседний воркспейс по кругу      |

### Скриншоты, OCR, экран

| Бинд                 | Действие                                                               |
| -------------------- | ---------------------------------------------------------------------- |
| `SUPER ALT + S`      | скриншот области → редактор satty                                      |
| `SUPER ALT + C`      | скриншот области → буфер                                               |
| `SUPER ALT + M`      | скриншот всего монитора → буфер                                        |
| `SUPER ALT + T/R/E`  | OCR области (rus+eng / rus / eng) → буфер                              |
| `SUPER ALT + A`      | закрепить область экрана поверх окон (`pin-screen.sh`)                 |
| `SUPER ALT + P`      | пипетка цвета (`colorpicker.sh` / hyprpicker)                          |
| `SUPER ALT + колесо` | живая лупа вокруг курсора (`zoom.sh`), `SUPER ALT + Backspace` — сброс |

### Утилиты и тема

| Бинд                 | Действие                                                  |
| -------------------- | --------------------------------------------------------- |
| `SUPER + A`          | переключить light/dark тему (`toggle-theme.sh`)           |
| `SUPER SHIFT + A`    | **ноутбук:** тумблер "крышка не усыпляет" (`lid-mode.sh`) |
| `SUPER + M`          | **ноутбук:** повернуть экран на 90° вместе с тачем и пером (`rotate-screen.sh next`) |
| `SUPER SHIFT + M`    | **ноутбук:** тумблер tablet-режима руками (`tablet-mode.sh toggle`) |
| `SUPER + B`          | история буфера (cliphist в rofi)                          |
| `SUPER SHIFT + B`    | эмодзи/математика/символы/каомодзи (rofimoji)             |
| `SUPER + Y`          | словарь wooordhunt в rofi                                 |
| `SUPER + U`          | перевод ru↔en через LibreTranslate                        |
| `SUPER + N`          | лента уведомлений, `SUPER SHIFT + N` — тумблер DND        |
| `SUPER + Delete`     | меню питания (то же на кнопку `XF86PowerOff`)             |
| `SUPER + G`          | снять эффекты, `SUPER SHIFT + G` — пикер шейдеров         |
| `SUPER CTRL + [ / ]` | софт-яркость через шейдер вниз/вверх, `Backspace` — сброс |
| `SUPER + Z`          | toggle waybar                                             |
| `SUPER + F12`        | лок сессии                                                |
| медиа/яркость        | `XF86Audio*` / `XF86MonBrightness*` → swayosd + playerctl |

### Тачскрин (ноутбук)

Сам Hyprland даёт тачскрину только тап и перетаскивание; жесты — плагин [hyprgrass](https://github.com/horriblename/hyprgrass) из `services/touch-gestures.nix`

| Жест                       | Действие                                                    |
| -------------------------- | ----------------------------------------------------------- |
| три пальца влево/вправо    | соседний воркспейс                                          |
| долгое нажатие двумя       | перетащить окно, в сетке — на сторону цели под пальцами     |
| долгое нажатие тремя       | ресайз окна                                                 |
| свайп от нижнего края      | меню приложений (`HUIX.menu`)                               |
| свайп от верхнего края     | войти в полноэкранный режим и выйти из него                 |
| свайп от правого/левого    | следующий/предыдущий воркспейс                              |

ПКМ двумя пальцами нет намеренно: тап не двигает указатель, синтетический клик лёг бы под мышь, а не под пальцы; контекстное меню по долгому нажатию рисуют сами приложения поверх `wl_touch`. У rofi и kitty на Wayland `wl_touch` нет вовсе — палец в них не работает, пока их не пропатчить

## Фиксы и тонкости

Накопленные костыли под конкретные баги:

- **Unreal Editor (`ue4-drag-empty-fix`)** — UE4/UnrealEditor плодит невидимые drag-окна с пустым `title`; правило `no_initial_focus + no_focus` для класса `^(UE4Editor|UnrealEditor)$` с пустым тайтлом, чтобы фокус не угонялся
- **XWayland drag-фикс (`fix-xwayland-drags`)** — пустые xwayland-окна перетаскивания (`class==""`, `title==""`) получают `no_focus`, иначе ломается DnD
- **`xwayland.force_zero_scaling = true`** — чтобы xwayland-приложения не были мыльными на дробном скейле
- **`suppress-maximize-events`** — глобально гасим запросы максимизации от всех приложений
- **файловые диалоги — во float вручную** — в Wayland компоновщик не знает, что окно является диалогом: `match:modal` в Hyprland читает только xwayland-флаг (`isModal()` смотрит `m_xwaylandSurface->m_modal`), а `xdg_tag` GTK не выставляет. Поэтому `float-portal-dialogs` ловит всё, что идёт через портал (класс `xdg-desktop-portal-gtk` — диалоги GTK4/Chromium/Electron), а приложения, рисующие GtkFileChooserDialog внутри себя, отличить от собственного окна нечем — у xarchiver (`float-xarchiver`) поэтому во float уходит всё приложение целиком`
- **hyprlock + `allow_session_lock_restore`** — краш локера оставляет сессию залоченной "красным экраном" (спасает только tty); опция разрешает новому инстансу перехватить лок
- **планшет Gaomon S630** прибит к выходу `DP-1` (ПК), иначе мапится на оба монитора
- **swayimg** — навигация и копирование в буфер забиндены и на латинице, и на кириллице (`c/с`, `h/р`, …), чтобы работало при любой раскладке
- **крышка ноутбука** — `SUPER SHIFT+A` → `lid-mode.sh` берёт лок `systemd-inhibit --what=handle-lid-switch`, и пока он держится, закрытие крышки не усыпляет систему, а только гасит встроенную панель. Лок работает только потому, что на ноутбуке выключен `LidSwitchIgnoreInhibited` (`nixos/laptop/logind.nix`); само `HandleLidSwitch` осталось дефолтным, так что вне сессии Hyprland крышка усыпляет как обычно. Режим сессионный — после ребута он выключен
- **tablet-режим ноутбука** (`services/tablet-mode.nix`) — сложенный трансформер ядро сообщает отдельным свитчем `Intel Virtual Switches` (`SW_TABLET_MODE`, не крышка), и Hyprland отдаёт его биндам `switch:on/off:<имя>` так же, как крышку; имя пишется один раз в `rokokol.hyprland.tabletModeSwitch` и уходит скрипту через `HUIX_TABLET_SWITCH`. `tablet-mode.sh on` поднимает два user-юнита — `huix-auto-rotate` (`rotate-screen.sh auto` слушает `monitor-sensor` из iio-sensor-proxy и крутит монитор, тач и перо через `hyprctl eval`) и `huix-virt-keyboard` (wvkbd, скрытая, пока кнопка в баре не попросит; слои en → цифры → ru → цифры) — и включает заголовки окон hyprbars (`plugin.hyprbars.enabled`, в конфиге они выключены). Свитч сообщает только изменения, а `hyprctl reload` сбрасывает transform и заголовки, поэтому `tablet-mode.sh sync` висит на событиях `hyprland.start` и `config.reloaded` и спрашивает состояние свитча через `evtest --query`. Состояние — активность юнита автоповорота, файла нет; вместо уведомлений о режиме служит кнопка ⌨️ в баре, которая есть только в режиме. Направление поворота от датчика (`left-up` → 1, `right-up` → 3) проверяется на живом ноуте
- **заголовки окон только в tablet-режиме** (`services/titlebars.nix`) — hyprbars с кнопками закрыть и развернуть (maximize, не fullscreen: полноэкранное окно накрывает свой же бар, и палец не вернулся бы), глифы Nerd Font из DepartureMono, цвета из палитры. Иконки hyprbars рисует жёстким `sans`, поэтому плагин пропатчен на `bar_text_font` — [WORKAROUNDS.md](../../../WORKAROUNDS.md). Окнам со своей рамкой (AyuGram, Obsidian, Super Productivity) и pin-окнам бара нет, список классов — в модуле. Перетаскивание за бар работает пальцем из коробки; `dwindle.precise_mouse_move` кладёт брошенное окно на ту сторону цели, где курсор, а не только в зазоры
- **`hyprctl` в эпоху Lua** — `hyprctl keyword` больше нет: опции ставятся через `hyprctl eval 'hl.config({...})'`, монитор — `hl.monitor({...})`, диспетчеры — `hyprctl dispatch 'hl.dsp...'`; `getoption` остался, но с точкой (`cursor.zoom_factor`). Так написаны `rotate-screen.sh`, `tablet-mode.sh`, `zoom.sh`, `lid-mode.sh`, `rofi-power.sh`, `colorpicker.sh` и hypridle, а screen-shader определяет эпоху сам одной пробой
- **плагины и ABI** — плагин собран против одной ревизии Hyprland и не грузится другой; здесь их держат в паре `follows` во `flake.nix`, а `nix flake update` должен двигать `hyprland`, `hyprgrass` и `hyprland-plugins` вместе, сверив ревизии Hyprland в их локах
- **вынесенные флейки** — [шейдеры и софт-яркость](https://github.com/rokokol/hyprland-screen-shader), [словарь](https://github.com/rokokol/rofi-wooordhunt) и [локскрин](https://github.com/rokokol/ddlc-hyprlock) живут в своих репо, тут остались только швы. Клавиши к ним — в `hyprland.lua`, как и все остальные, а команду лока `services/hypridle.nix` берёт из `ddlc.hyprlock.lockCommand` — движок диалога обязан быть родителем hyprlock, поэтому звать `hyprlock` напрямую нельзя
