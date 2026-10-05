# NixOS-слой

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](services/README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](fonts/README.md)

Тут живёт всё системное: загрузка, железо, GPU, сеть, ядро, системные сервисы и юзеры. Если правка касается `/etc` или systemd-system юнита — она сюда, а не в [Home Manager](../home-manager/README.md)

`configuration-<host>.nix` — точка входа хоста (импорты и флаги `rokokol.*.enable`), `default.nix` с `boot`, `sound` и `system` — общая база всех хостов, `pc/`, `laptop/` и `station/` — железо и то, что есть только у одного хоста, `desktop/` — базовые опции рабочего стола и xdg-портал, [`services/`](services/README.md) и [`fonts/`](fonts/README.md) — по своему README. Входы, оверлеи и общие аргументы — во [`flake.nix`](../flake.nix)

Рабочий стол включается одним флагом `rokokol.workstation.enable`: его ставят ПК и ноут, а каждый десктопный модуль по умолчанию следует за ним и выключается отдельно. Станция флаг не ставит и получает из тех же модулей систему без графики

## Станция

Домашний сервер без экрана, который принимает бэкапы остальных машин. Диск размечен декларативно через disko: системный раздел и отдельный том под бэкапы, оба на btrfs, раз в месяц их проверяет scrub. Адрес в локалке постоянный, шелл — только Tailscale SSH, на случай упавшего тайлнета остаётся вход с консоли. Секреты у станции свои, в `secrets/station.yaml` под собственным ключом, так что секреты десктопов ей недоступны. Сбой важного юнита приходит письмом, а командой `wake-pc` станция будит ПК, который со своей стороны принимает magic packet
