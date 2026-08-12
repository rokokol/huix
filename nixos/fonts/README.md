# Шрифты

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](../services/README.md)

Шрифты, которые лежат прямо в репо файлами, а не тянутся пакетом: `fonts.nix` собирает крошечную `stdenv.mkDerivation`, которая раскладывает `*.ttf` в `truetype/`, `*.otf` в `opentype/` и отдаёт всё в `fonts.packages`. Кинуть новый шрифт сюда файлом достаточно — сборка подхватит его сама, прописывать отдельно не надо

Кроме файловых, пакетами тянутся `inter` и `Spectral` (через `google-fonts.override { fonts = [ "Spectral" ]; }`). Дефолты `fontconfig`:

| Роль        | Шрифт                        |
| ----------- | ---------------------------- |
| `monospace` | DepartureMono Nerd Font Mono |
| `sansSerif` | Spectral                     |
| `serif`     | Spectral                     |

`Doki` во всех вариантах — игровой шрифт DDLC, принадлежит Team Salvato, см. [ASSETS.md](../../ASSETS.md). `DokiNerdFontMono-Regular.otf` я собрал из него сам по приколу: нердфонтный моно `Doki` выглядит абсолютно проклято, поэтому лежит тут экспонатом
