# NixOS-слой

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](services/README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](fonts/README.md)

Тут живёт всё системное: загрузка, железо, GPU, сеть, ядро, системные сервисы и юзеры. Если правка касается `/etc` или systemd-system юнита — она сюда, а не в [Home Manager](../home-manager/README.md)

Хосты собираются слоями, правь самый узкий из подходящих: `configuration-<host>.nix` — точка входа хоста (импорты и флаги `rokokol.*.enable`), `default.nix` + `boot/sound/system.nix` — общий baseline обоих хостов, `pc/` и `laptop/` — железо и host-specific опции, `desktop/` — core-опции и xdg-портал, [`services/`](services/README.md) и [`fonts/`](fonts/README.md) — по своему README. Inputs, overlays и `specialArgs` — во [`flake.nix`](../flake.nix)

## Тонкости

- `system.stateVersion` зафиксирован на `25.11` — не трогай без явной миграции
- `users.users.<имя>.extraGroups` доезжает из нескольких модулей (`system.nix`, `nvidia.nix`, `docker.nix`, `virtualization.nix`) — Nix их мёрджит, но при дебаге прав грепай весь `nixos/`, а не один файл
- на ПК NTFS-раздел с меткой `govno` монтируется в `/home/rokokol/govno` с `nofail` — отсутствие маунта не ломает boot, но ломает часть `xdg.userDirs`
