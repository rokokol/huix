# NixOS-слой

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](services/README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](fonts/README.md)

Тут живёт всё системное: загрузка, железо, GPU, сеть, ядро, системные сервисы и юзеры. Если правка касается `/etc` или systemd-system юнита — она сюда, а не в [Home Manager](../home-manager/README.md)

`configuration-<host>.nix` — точка входа хоста (импорты и флаги `rokokol.*.enable`), `default.nix` с `boot`, `sound` и `system` — общая база обоих хостов, `pc/` и `laptop/` — железо и то, что есть только у одного хоста, `desktop/` — базовые опции рабочего стола и xdg-портал, [`services/`](services/README.md) и [`fonts/`](fonts/README.md) — по своему README. Входы, оверлеи и общие аргументы — во [`flake.nix`](../flake.nix)
