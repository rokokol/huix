<div align="center">

<img src="../../assets/Сайори%20в%20коробке.jpg" alt="каждый сервис в своей коробочке" width="300"/>

<em>каждый сервис разложен аккуратно по своей коробочке</em>

</div>

# Сервисы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](../fonts/README.md)

Системные сервисы, разложенные по категориям. Каждый сервис — отдельный модуль, а *какие* из них включены на хосте решает агрегатор `services-<host>.nix`. Чтобы добавить или убрать сервис с хоста — правь агрегатор, а не сам модуль

## Категории

| Каталог | Что там |
| --- | --- |
| `ai/` | `ollama` (на ПК подменяется на `ollama-cuda`), `comfyui`, `openwebui` |
| `desktop/` | `amnezia-vpn`, `file-manager`, `sddm`, `ssh-askpass`, `wl-clip-persist` |
| `devices/` | `printer`, `tablet`, `virtual-camera` |
| `system/` | `appimage`, `cachix`, `nix-ld` |
| `tools/` | `jupyter`, `libre-translate`, `searxng`, `syncthing` |
| `utils/` | `docker`, `embedded`, `tor`, `virtualization`, `zapret` |

## Кто где включён

Общие для обоих хостов:

- `ai/ollama` — локальные LLM (ПК тянет CUDA-сборку, ноут CPU-only)
- `desktop/amnezia-vpn` — VPN-клиент
- `desktop/file-manager`, `desktop/sddm`, `desktop/ssh-askpass`, `desktop/wl-clip-persist`
- `system/appimage` — прямой запуск *.AppImage (binfmt) + `steam-run` (FHS-песочница)
- `system/cachix` — бинарные кэши
- `system/nix-ld` — запуск динамических не-Nix бинарей (FHS-набор библиотек)
- `tools/jupyter` (на ПК с CUDA), `tools/libre-translate`, `tools/syncthing`
- `utils/docker`
- `utils/embedded` — тулчейны AVR/ESP/STM32/RP2040 + udev (platformio)

Только ПК:

- `ai/comfyui` — слоп-машина картинок (через flakehub `comfyui-nix`)
- `ai/openwebui` — веб-морда к Ollama
- `devices/printer`, `devices/tablet`, `devices/virtual-camera`
- `tools/searxng` — приватный метапоиск за nginx
- `utils/virtualization` (libvirtd + KVM/AMD + vfio)

Только ноут:

- `utils/tor` — Tor через webtunnel-мосты

## Порты и биндинги

Всё биндится на `127.0.0.1`, наружу не торчит ничего — firewall под эти сервисы не открыт. Менять биндинг без причины не надо; если правда нужно выставить наружу — открывай порт явно в том же модуле

| Сервис | Порт |
| --- | --- |
| Ollama | 11434 |
| Open WebUI (ПК) | 8088 |
| ComfyUI (ПК) | 8188 |
| SearxNG (ПК, за nginx) | 9000 |
| Jupyter Lab | 8888 |
| LibreTranslate | 5000 |
| Syncthing GUI | 8384 |

Порты экспортятся как session variables (`OPEN_WEBUI_PORT`, `COMFYUI_PORT`, `SYNCTHING_PORT`, `LIBRE_TRANSLATE_PORT`) — удобно дёргать из скриптов и алиасов

## Тонкости

- кастомные опции живут под `custom.*` — пока есть только `custom.jupyter.{enable,withCuda}` (см. `tools/jupyter.nix`). Не гейти поведение через `mkIf config.services.foo.enable` из чужого модуля — заводи свою опцию
- Jupyter на ПК берёт `pkgs.stable.python3` с бинарными `torch*`, чтобы не собирать ML-стек из исходников
- тяжёлые сборки ускоряются кэшами `cuda-maintainers` (ПК, объявлен в `nixos/pc/nvidia.nix`) и `comfyui` (ПК) — при добавлении тяжёлого билда лучше дописать substituter, чем пересобирать

