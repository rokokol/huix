<div align="center">

<img src="../../assets/say-sketch2.webp" alt="say sketch" width="280"/>

</div>

# Программы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](nixvim/README.md)

Сюда попадают конфиги для программ, которые занимают больше одной строки в `home.packages`. Например, если тянут какие-то свои дополнительные зависимости или имеют нужные мне декларативные настройки. Или просто связанные с ними штуки (_≧m≦_)

Файл на программу; сгруппированы только шелл-утилиты (`cli/`), терминал с шеллом (`term/`) и [`nixvim/`](nixvim/README.md). Host-специфики тут нет — программы общие для обоих хостов, разводка по хостам живет в [пакеты desktop-слоя](../desktop/packages)

## Тонкости

- часть файлов — это швы к вынесенным флейкам, и в них только включение и то, чего флейк не везёт: `virtual-mic.nix` → [virtual-media-devices](https://github.com/rokokol/virtual-media-devices) (камерная половина того же флейка включается системным слоем — ей нужен модуль ядра), `cli/claude.nix` → [claude-account](https://github.com/rokokol/claude-account), `rofi.nix` → [ddlc-rofi-theme](https://github.com/rokokol/ddlc-rofi-theme) плюс настройки шрифтов `Doki` и `DepartureMono`, которых в темах нет
- содержимое Клода тут не декларируется совсем — `settings.json`, `skills/`, `plugins/`, `commands/`, `agents/` живут в `~/.local/share/claude-shared` обычными файлами и ездят между хостами Syncthing'ом
