<div align="center">

<img src="../assets/shef-os-320-kg.jpg" alt="шеф готовит утилиты" width="300"/>

<em>320kg scripts 💀</em>

</div>

# Скрипты

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)

Рукописные shell-обёртки, рассчитанные на путь `$HUIX/scripts`. Лежат обычным bash-ом в живом чекауте, а не собираются в store: правка применяется сразу, без `nixos-rebuild` — можно допиливать скрипт по ходу дела и тут же дёргать его тем же биндом. Nix держит только список зависимостей, и даже те скрипты, что выставлены командами, обёрнуты через `writeShellApplication` в один `exec bash "$HUIX/scripts/<имя>.sh"` — в store уезжает обёртка, а не тело

Кто их зовёт — видно с той стороны: бинды в [`hyprland.lua`](../home-manager/desktop/hyprland/README.md#хоткеи), systemd-юниты и Nix-обёртки (`writeShellApplication`, которые кладут зависимости в PATH) из [программ](../home-manager/programs/README.md). Что делает конкретный и как его звать — его `--help`, а в шапке только то, что нужно при правке

Общее для нескольких скриптов лежит в `lib/`: `lib/hyprland.sh` знает, как найти встроенную панель ноутбука (`internal_monitor`), и его `source`-ят `lid-mode.sh` и `rotate-screen.sh`. Скрипты говорят с Hyprland эпохи Lua: `hyprctl eval 'hl.config({...})'` вместо `hyprctl keyword`, `hyprctl dispatch 'hl.dsp...'` вместо старых слов

## Тесты

`tests/run.sh` гоняет `rotate-screen.sh`, `tablet-mode.sh` и `memory-status.sh` против стабов `hyprctl`, `monitor-sensor`, `systemctl`, `evtest`, `pkill` и `notify-send`, которые записывают, что их попросили, и отвечают из переменных окружения — так каждый вызов, который скрипт отдаёт компоситору, проверяется без компоситора. То же делает `nix flake check` через `checks.script-tests`, в песочнице без `/usr/bin/env`, поэтому раннер запускает скрипты через `bash` и подменяет шебанги стабов

## Тонкости

- **`rotate-screen.sh`** переписывает правило монитора целиком (`hl.monitor` не умеет менять одно поле): режим, позицию и scale он читает из `hyprctl monitors -j` и отдаёт обратно с новым transform, а следом ставит `input.touchdevice.transform` и `input.tablet.transform` — они глобальные и за монитором сами не следуют. `auto` слушает `monitor-sensor` и переводит `normal`/`left-up`/`bottom-up`/`right-up` в 0/1/2/3
- **`tablet-mode.sh`** держит состояние в активности юнита `huix-auto-rotate`, а не в файле; `sync` находит свитч по имени из `HUIX_TABLET_SWITCH` в `/proc/bus/input/devices` и спрашивает его через `evtest --query` (код 10 — включён); `virt-keyboard status` печатает JSON для кнопки в баре
- **`memory-status.sh`** считает занятую RAM как `MemTotal - MemAvailable` и красит класс `swap` от порога `-w`, который приходит из `rokokol.waybar.swapWarnMb`

- **`sync.sh` автоматом только перематывает вперёд** (`--pull-only` из юнита), а историю пишет `syssync`. Так, конфиг живёт по GitOps
- **Оба режима в конце подтягивают и `~/Projects`, и общие скиллы Клода** — какие именно каталоги, говорят `PROJECTS_DIR` и `SKILLS_DIR`: обе переменные объявлены в `home.sessionVariables`, поэтому ручной `syssync` обходит ровно то же, что юнит. Обход рекурсивный, но находит `.git` и останавливается на этой папке, не заходя в её вложенные каталоги. Репозиторий без своих коммитов перематывается вперёд, со своими коммитами ребейзится поверх upstream с автостэшем. Конфликтный ребейз откатывается целиком: недоделанный ребейз, оставленный фоновой задачей при логине, хуже отставшего чекаута. Коммитов и пушей обход не делает никогда. Исключает репозиторий файл `nosync` **внутри `.git/`** — там он не просит `.gitignore` и не светится в `git status`. Отключается флагом `--no-projects`
- **`git-hooks/` — это хуки git, а не команды**: `prepare-commit-msg` ставит `[имя-хоста]` в начало subject'а любого коммита в этом репозитории, `commit-msg` не даёт закоммитить сообщение, в котором кроме префикса ничего нет. Подключаются через `core.hooksPath` из `includeIf` по `huixDir` — в других репозиториях хуков нет. Имена без `.sh` и без kebab-case-вольностей: git ищет ровно такие
- пути не хардкодятся. Использую `$HUIX` в скриптах и `huixDir` в Nix
- рантайм-state (тема, шейдер) лежит в `~/.local/state/huix/`, поэтому он переживает логаут и ребут
