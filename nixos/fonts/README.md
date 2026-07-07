# Шрифты

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](../services/README.md)

Системные шрифты, которые лежат прямо в репо файлами, а не тянутся пакетом. `fonts.nix` собирает крошечную `stdenv.mkDerivation`, которая раскладывает `*.ttf` в `truetype/`, а `*.otf` в `opentype/` и отдаёт всё в `fonts.packages`

Помню как я сделал из эксперимента `DokiNerdFontMono-Regular.otf`. Нердфонтный моно `Doki` шрифт выглядиит абсолютно проклято. Поэтому оставил просто как артефакт и экспонат тут, хех

Кроме файловых, пакетами тянутся `inter` и `Spectral` (через `google-fonts.override { fonts = [ "Spectral" ]; }`). Дефолты `fontconfig`:

| Роль | Шрифт |
| --- | --- |
| `monospace` | DepartureMono Nerd Font Mono |
| `sansSerif` | Spectral |
| `serif` | Spectral |

## Применение

Можно кинуть новый шрифт сюда файлом — и он сам подхватится сборкой, отдельно прописывать не надо. После — обычный `rebuild`