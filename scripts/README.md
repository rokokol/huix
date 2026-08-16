<div align="center">

<img src="../assets/shef-os-320-kg.jpg" alt="шеф готовит утилиты" width="300"/>

<em>320kg scripts 💀</em>

</div>

# Скрипты

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)

Рукописные shell-обёртки, рассчитанные на путь `$HUIX/scripts`. Лежат обычным bash-ом в живом чекауте, а не собираются в store: правка применяется сразу, без `nixos-rebuild` — можно допиливать скрипт по ходу дела и тут же дёргать его тем же биндом. Nix держит только список зависимостей, и даже те скрипты, что выставлены командами, обёрнуты через `writeShellApplication` в один `exec bash "$HUIX/scripts/<имя>.sh"` — в store уезжает обёртка, а не тело

Кто их зовёт — видно с той стороны: бинды в [`hyprland.conf`](../home-manager/desktop/hyprland/README.md#хоткеи), systemd-юниты и Nix-обёртки (`writeShellApplication`, которые кладут зависимости в PATH) из [программ](../home-manager/programs/README.md). Что делает конкретный — его шапка и `usage`

## Тонкости

- **`sync.sh` автоматом только перематывает вперёд** (`--pull-only` из юнита), а историю пишет `syssync` руками — конфиг живёт по GitOps: в upstream уезжает ровно то, что ты сам закоммитил
- пути не хардкодятся. Использую `$HUIX` в скриптах и `huixDir` в Nix
- рантайм-state (тема, шейдер) лежит в `~/.local/state/huix/`, поэтому он переживает логаут и ребут
