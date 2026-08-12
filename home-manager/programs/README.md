<div align="center">

<img src="../../assets/say-sketch2.webp" alt="say sketch" width="280"/>

</div>

# Программы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](nixvim/README.md)

Сюда попадают конфиги для программ, которые занимают больше одной строки в `home.packages`. Например, если тянут какие-то свои дополнительные зависимости или имеют нужные мне декларативные настройки. Или просто связанные с ними штуки (*≧m≦*)

Файл на программу; сгруппированы только шелл-утилиты (`cli/`), терминал с шеллом (`term/`) и [`nixvim/`](nixvim/README.md). Host-специфики тут нет — программы общие для обоих хостов, разводка по хостам уезжает в [пакеты desktop-слоя](../desktop/packages)

## Тонкости

- часть файлов — это швы к вынесенным флейкам, и в них только включение да то, чего флейк не везёт: `virtual-mic.nix` → [virtual-media-devices](https://github.com/rokokol/virtual-media-devices) (камерная половина того же флейка включается системным слоем — ей нужен модуль ядра), `cli/claude.nix` → [claude-account](https://github.com/rokokol/claude-account), `rofi.nix` → [ddlc-rofi-theme](https://github.com/rokokol/ddlc-rofi-theme) плюс шрифты `Doki` и `DepartureMono`, которых в теме нет
- светлое/тёмное у rofi рантаймовое: симлинк `~/.config/rofi/themes/ddlc.rasi` переставляет команда `ddlc-rofi-theme`, её и зовёт `scripts/toggle-theme.sh` по `SUPER+A`
- содержимое Клода тут не декларируется совсем — `settings.json`, `skills/`, `plugins/`, `commands/`, `agents/` живут в `~/.local/share/claude-shared` обычными файлами и ездят между хостами Syncthing'ом; HM положил бы туда симлинк в `/nix/store/<хеш-генерации>/…`, который на втором хосте приехал бы битым. Плата за общую папку: singleton-файлы (`settings.json`, `MEMORY.md`) при одновременной правке дают `.sync-conflict-*`, а `history.jsonl` пишут обе машины и строки могут перемешаться. Куки не синкаются — `/login` на каждом хосте свой
- `CLAUDE_CONFIG_DIR` из модуля прибит константой `$HOME/.claude` — это не "путь профиля", а именно дефолтный каталог конфига. Нужен, только чтобы `.claude.json` лёг **внутрь** профиля: бинарник ищет его рядом с каталогом и переписывает через `rename(2)`, который заменил бы симлинк по такому пути обычным файлом и молча сломал изоляцию аккаунтов
