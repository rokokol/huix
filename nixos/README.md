# NixOS-слой

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](services/README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](fonts/README.md)

Тут живёт всё системное: загрузка, железо, GPU, сеть, ядро, системные сервисы и юзеры. Если правка касается `/etc` или systemd-system юнита — она сюда, а не в [Home Manager](../home-manager/README.md)

Хосты собираются слоями, правь самый узкий из подходящих:

| Файл / каталог | Что внутри |
| --- | --- |
| `configuration-pc.nix` | точка входа ПК: импорты, `ollama-cuda`, флаги `custom.*` (comfyui, openwebui, searxng, printer, tablet, virtualCamera, virtualization, jupyter+CUDA) |
| `configuration-laptop.nix` | точка входа ноута: импорты, `ollama-cpu`, `custom.jupyter` |
| `default.nix` | общий для обоих хостов слой — desktop + шрифты |
| `desktop/` | core-options и xdg-портал |
| `fonts/` | системные шрифты, см. [fonts/README.md](fonts/README.md) |
| `pc/` | железо ПК: boot, hardware, nvidia, sound, keyboard, system, options |
| `laptop/` | железо ноута: boot, hardware, keyboard, system, options |
| `services/` | системные сервисы, см. [services/README.md](services/README.md) |

## Где что менять

- общую архитектуру, inputs, overlays, `specialArgs` — в [`flake.nix`](../flake.nix)
- какие модули подключены на хосте — в `configuration-<host>.nix`
- host-specific опции, boot, GPU, клавиатуру — в `pc/*` или `laptop/*`
- базовые настройки (hostname, юзер, locale, Nix GC, ФС) — в `pc/system.nix` / `laptop/system.nix`
- набор включённых сервисов — флаги `custom.*.enable` в `configuration-<host>.nix` (все модули импортирует общий `services/default.nix`)

## Тонкости

- `system.stateVersion` зафиксирован на `25.11` — не трогай без явной миграции
- `users.users.<имя>.extraGroups` доезжает из нескольких модулей (`system.nix`, `nvidia.nix`, `docker.nix`, `virtualization.nix`) — Nix их мёрджит, но при дебаге прав грепай весь `nixos/`, а не один файл
- на ПК NTFS-раздел с меткой `govno` монтируется в `/home/rokokol/govno` с `nofail` — отсутствие маунта не ломает boot, но ломает часть `xdg.userDirs`

## Применение

```sh
sudo nixos-rebuild switch --flake .#nixos-pc
sudo nixos-rebuild switch --flake .#nixos-laptop
```