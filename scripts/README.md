<div align="center">

<img src="../assets/shef-os-320-kg.jpg" alt="шеф готовит утилиты" width="300"/>

<em>320kg scripts 💀</em>

</div>

# Скрипты

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)

Рукописные shell-обёртки, рассчитанные на путь `$HUIX/scripts`. Лежат обычным bash-ом в живом чекауте, а не собираются в store: правка применяется сразу, без `nixos-rebuild` — можно допиливать скрипт по ходу дела и тут же дёргать его тем же биндом. Nix держит только список зависимостей, и даже те скрипты, что выставлены командами, обёрнуты через `writeShellApplication` в один `exec bash "$HUIX/scripts/<имя>.sh"` — в store уезжает обёртка, а не тело

Кто их зовёт — видно с той стороны: бинды в [`hyprland.conf`](../home-manager/desktop/hyprland/README.md#хоткеи), systemd-юниты и Nix-обёртки (`writeShellApplication`, которые кладут зависимости в PATH) из [программ](../home-manager/programs/README.md). Что делает конкретный — его шапка и `usage`

## Тонкости

- **`sync.sh` коммитит и пушит всё застейдженное** на старте сессии и после каждого `nixos-rebuild` — не оставляй в дереве то, чего не хочешь видеть в истории. При этом он делает `add -u` (только отслеживаемые), так что новый файл, забытый без `git add`, тихо не уедет в upstream
- пути не хардкодь — бери `$HUIX` в скриптах и `huixDir` в Nix
- рантайм-state (тема, шейдер) лежит в `~/.local/state/huix/` — он переживает логаут и ребут, а на reload Hyprland восстанавливается
