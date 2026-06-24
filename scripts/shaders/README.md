# Полноэкранные шейдеры Hyprland + софт-яркость

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](../README.md)

Набор полноэкранных эффектов для Hyprland и софтверное затемнение экрана через
хоткеи. Управляется одним менеджером `scripts/screen-shader.sh`

## Зачем

Hyprland держит **только один** слот шейдера (`decoration:screen_shader`),
поэтому цветовой эффект и затемнение нельзя включить независимо. Менеджер их
**композирует**: каждый эффект описывает лишь функцию `vec3 effect(...)`, а
скрипт собирает из неё + уровня яркости финальный шейдер и применяет его. На
десктопе нет аппаратной подсветки — затемнение чисто программное (умножение
цвета), поэтому может уходить ниже "железного" минимума

## Файлы

| Файл | Что это |
|------|---------|
| `scripts/screen-shader.sh` | менеджер: состояние, сборка шейдера, режимы отрисовки, индикатор |
| `scripts/shaders/<name>.frag` | один эффект = одна функция `vec3 effect(vec3 c, vec2 uv)` |
| `scripts/rofi-shader.sh` | пикер эффектов как rofi script-modi (`shader`) |
| `~/.local/state/huix/shader` | durable-состояние (effect, bright, slot) — переживает логаут/ребут |
| `$XDG_RUNTIME_DIR/hypr-shader/active-{0,1}.frag` | сгенерированные шейдеры (эфемерны) |

## Хоткеи

| Клавиши | Действие |
|---------|----------|
| `SUPER+G` | если эффект активен — выключить; если нет — включить ч/б (`off-or grayscale`) |
| `SUPER+SHIFT+G` | rofi-пикер всех эффектов |
| `SUPER+ALT+]` / `[` | яркость +/− 0.10 (зажатие повторяет) |
| `SUPER+ALT+\` | сброс яркости в 1.00 |

Индикатор в waybar (`custom/shader`, только ПК): ЛКМ — пикер, ПКМ — снять
эффект, колесо — яркость. Прячется, когда эффекта нет и яркость 100%

## Команды менеджера

```sh
screen-shader.sh effect set <name>     # поставить эффект
screen-shader.sh effect off-or <name>  # есть эффект -> выкл; нет -> включить <name>
screen-shader.sh effect next|prev      # листать по кругу
screen-shader.sh bright up|down        # яркость ±0.10 (кламп 0.10..1.00)
screen-shader.sh bright reset|set <v>  # сброс / точное значение
screen-shader.sh restore               # перечитать состояние и применить (на reload)
screen-shader.sh status                # JSON для waybar (эмодзи + %)
screen-shader.sh menu                  # список "<эмодзи> <подпись>|<значение>"
```

## Эффекты

`none` (только затемнение), `grayscale`, `sepia`, `invert`, `warm` (ночной),
`cool`, `vignette`, `crt` (кинескоп: кривизна + RGB-маска + скан-линии),
`matrix` (зелёный дождь), `posterize`, `wave`, `glitch`

`menu`/`EMOJI`/`LABEL` в `screen-shader.sh` — **единственный** источник эмодзи и
подписей; rofi-пикер и индикатор waybar тянут их оттуда

## Как добавить эффект

1. Создать `scripts/shaders/<name>.frag` с **только** функцией
   `vec3 effect(vec3 c, vec2 uv)` (без `#version`, `main`, объявлений — их
   добавит менеджер). Доступны: `c` (цвет пикселя), `uv` (0..1), `tex`
   (sampler), `time` (секунды — использование включает анимацию), `BRIGHTNESS`.
2. Добавить имя в массив `EFFECTS` (порядок листания) и в карты `EMOJI`/`LABEL`.
3. Если эффект анимированный — в `ANIMATED`; со смещённой выборкой (кривизна) —
   в `OFFSET`; геометрически искажает — в `WARP`.
4. `git add` новый файл (hourly-sync берёт только отслеживаемые).
5. Проверить компиляцию:
   `nix shell nixpkgs#glslang -c glslangValidator -S frag <собранный шейдер>`.

## Три режима отрисовки

Менеджер сам выставляет `debug:damage_tracking` и `debug:vfr` под тип эффекта:

| Режим | Эффекты | damage / vfr | Почему |
|-------|---------|--------------|--------|
| `animated` | `ANIMATED` (wave, glitch, matrix) | `0` / `0` | используют `time` → нужен кадр каждый тик; при VFR Hyprland уходит в idle и анимация дёргается |
| `fullstatic` | `OFFSET` (crt) | `1` / `1` | смещённая выборка ломается при точном damage; перерисовываем весь монитор на любое изменение, но в простое спим |
| `default` | остальные | `2` / `1` | попиксельный эффект, частичный damage ок |

`WARP`-эффекты дополнительно включают **программный** курсор
(`cursor:no_hardware_cursors true`), чтобы он шёл через шейдер вместе с экраном
(иначе у искажённых краёв клики визуально "уезжают")

## Персистентность и индикатор (важные тонкости)

- **Состояние durable** в `~/.local/state/huix/shader` (не в git-дереве). На
  reload Hyprland `exec = screen-shader.sh restore` применяет его заново — иначе
  `screen_shader` (рантайм-only) слетает после ребилда/перелогина
- **Чередование `active-0/active-1.frag`**: Hyprland не перечитывает шейдер, если
  путь не изменился, поэтому пишем в попеременные файлы — иначе смена яркости при
  активном эффекте не применяется
- **Индикатор waybar обновляется сигналом** `SIGRTMIN+N`, где `N` задаётся
  **один раз** в `waybar-pc.nix` (`shaderSignal`) и пробрасывается скрипту через
  `WAYBAR_SHADER_SIGNAL`. После смены состояния скрипт шлёт `pkill -RTMIN+N
  waybar` — это не "убить", а "перечитай модуль" (у RT-сигналов есть обработчик
  в waybar). **НО** дефолтное действие RT-сигнала — завершить процесс, поэтому
  на старте сессии `restore` сигнал НЕ шлёт (`SHADER_NO_SIGNAL`): иначе ранний
  сигнал убьёт ещё не готовый waybar. На старте он и не нужен — waybar сам читает
  `status` своим `exec`-ом
