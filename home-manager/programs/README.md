<div align="center">

<img src="../../assets/say-sketch2.webp" alt="say sketch" width="280"/>

</div>

# Программы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](nixvim/README.md)
[![rofi](https://img.shields.io/badge/rofi-лаунчер-EE2A7B?style=for-the-badge)](rofi/README.md)

Сюда попадают конфиги для программ, которые занимают больше одной строки в `home.packages`. Например, если тянут какие-то свои дополнительные зависимости или имеют нужные мне декларативные настройки. Или просто связанные с ними штуки (*≧m≦*)

## Что внутри

| Файл / каталог | Что это |
| --- | --- |
| `alarm.nix` | будильник: обёртка над `scripts/alarm.sh`, кладёт зависимости в PATH и звук из freedesktop-темы |
| `cli/` | шелл-утилиты: `btop`, `git`, `ssh`, `direnv`, `claude/` (два аккаунта Claude Code на одной машине) |
| `term/` | терминал и шелл: `kitty`, `starship`, `zsh` |
| `nixvim/` | Neovim через Nixvim, см. [nixvim/README.md](nixvim/README.md) |
| `rofi/` | лаунчер rofi с темами, см. [rofi/README.md](rofi/README.md) |
| `thunar.nix` | файловый менеджер + экшен "Open Terminal Here" + mime-дефолты для папок |
| `virtual-mic.nix` | виртуальный микрофон: обёртка над `scripts/virtual-mic.sh` |
| `zen.nix` | браузер Zen с модами и поисковыми движками |

## Тонкости

- `alarm.nix` и `virtual-mic.nix` — тонкие Nix-обёртки, вся логика живёт в [`scripts/`](../../scripts/README.md), Nix только собирает PATH и прокидывает аргументы
- `cli/claude.nix` ставит стоковый `pkgs.claude-code` и включает модуль флейка [claude-account](https://github.com/rokokol/claude-account): обёртки нет, `~/.claude` — симлинк на активный профиль, а `CLAUDE_CONFIG_DIR` и починка симлинков на активации приходят из модуля. Ничего из содержимого Клода тут не декларируется — `settings.json`, `skills/`, `plugins/`, `commands/`, `agents/` и статусная строка живут в `~/.local/share/claude-shared` и ездят между хостами через Syncthing; store-симлинк в синкаемой папке приехал бы на второй хост битым
- `*-pc`/`*-laptop` разводки здесь нет — программы общие для обоих хостов, host-специфика уезжает в [пакеты desktop-слоя](../desktop/packages)
- `term/zsh.nix` содержит алиасы для терминала

