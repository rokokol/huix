<div align="center">

<img src="../../assets/sayori-v-korobke.jpg" alt="каждый сервис в своей коробочке" width="300"/>

<em>каждый сервис разложен аккуратно по своей коробочке</em>

</div>

# Сервисы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](../fonts/README.md)
[![DDLC](https://img.shields.io/badge/DDLC-тема_логина-FF80C0?style=for-the-badge&logo=qt&logoColor=white)](desktop/sddm-ddlc/README.md)

Системные сервисы, разложенные по категориям. Каждый сервис — отдельный модуль; `default.nix` — единый агрегатор, импортирующий всё на обоих хостах. Общие сервисы включены безусловно, хост-специфичные гейтятся опцией `custom.<имя>.enable` внутри своего модуля, а *вход* — какие флаги подняты — объявляет `configuration-<host>.nix`. Чтобы добавить/убрать сервис с хоста — щёлкай флаг там, а не правь модуль

## Категории

| Каталог | Что там |
| --- | --- |
| `ai/` | `ollama` (на ПК подменяется на `ollama-cuda`), `comfyui`, `openwebui` |
| `desktop/` | `amnezia-vpn`, `file-manager`, `sddm` (+ [DDLC-тема](desktop/sddm-ddlc/README.md)), `ssh-askpass` |
| `devices/` | `meshtastic`, `printer`, `tablet`, `virtual-camera` |
| `system/` | `appimage`, `cachix`, `nix-ld` |
| `tools/` | `jupyter`, `libre-translate`, `searxng`, `syncthing` |
| `utils/` | `docker`, `embedded`, `tor`, `virtualization` |

## Кто где включён

Общие для обоих хостов:

- `ai/ollama` — локальные LLM (ПК тянет CUDA-сборку, ноут CPU-only)
- `desktop/amnezia-vpn` — VPN-клиент
- `desktop/file-manager`, `desktop/sddm` — экран логина в стиле DDLC ([подробнее](desktop/sddm-ddlc/README.md)), `desktop/ssh-askpass`
- `system/appimage` — прямой запуск *.AppImage (binfmt) + `steam-run` (FHS-песочница)
- `system/cachix` — бинарные кэши
- `system/nix-ld` — запуск динамических не-Nix бинарей (FHS-набор библиотек)
- `tools/jupyter` (на ПК с CUDA), `tools/libre-translate`, `tools/syncthing`
- `devices/meshtastic` — нативная Meshtastic-нода (`meshtasticd` + веб-интерфейс) — `custom.meshtastic.enable`
- `utils/docker`
- `utils/embedded` — тулчейны AVR/ESP/STM32/RP2040 + udev (platformio)
- `utils/tor` — Tor через webtunnel-мосты

Только ПК (флаги `custom.*.enable` в `configuration-pc.nix`):

- `ai/comfyui` — слоп-машина картинок (через flakehub `comfyui-nix`) — `custom.comfyui.enable`
- `ai/openwebui` — веб-морда к Ollama — `custom.openwebui.enable`
- `devices/printer`, `devices/tablet`, `devices/virtual-camera` — `custom.{printer,tablet,virtualCamera}.enable`
- `tools/searxng` — приватный метапоиск за nginx — `custom.searxng.enable`
- `utils/virtualization` (libvirtd + KVM/AMD + vfio) — `custom.virtualization.enable`

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
| Meshtastic Web | 9443 |
| Syncthing GUI | 8384 |

Порты экспортятся как session variables (`OPEN_WEBUI_PORT`, `COMFYUI_PORT`, `SYNCTHING_PORT`, `LIBRE_TRANSLATE_PORT`, `MESHTASTIC_PORT`) — удобно дёргать из скриптов и алиасов

## Тонкости

- кастомные опции живут под `custom.*`: `custom.jupyter.{enable,withCuda}` плюс enable-флаги хост-специфичных сервисов (`comfyui`, `openwebui`, `searxng`, `meshtastic`, `printer`, `tablet`, `virtualCamera`, `virtualization`). Опция объявляется в самом модуле, включается в `configuration-<host>.nix`. Не гейти поведение через `mkIf config.services.foo.enable` из чужого модуля — заводи свою опцию
- Jupyter на ПК берёт `pkgs.stable.python3` с бинарными `torch*`, чтобы не собирать ML-стек из исходников
- тяжёлые сборки ускоряются кэшами `cuda-maintainers` (ПК, объявлен в `nixos/pc/nvidia.nix`) и `comfyui` (ПК) — при добавлении тяжёлого билда лучше дописать substituter, чем пересобирать

