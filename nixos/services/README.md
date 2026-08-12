<div align="center">

<img src="../../assets/sayori-v-korobke.jpg" alt="каждый сервис в своей коробочке" width="300"/>

<em>каждый сервис разложен аккуратно по своей коробочке</em>

</div>

# Сервисы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](../fonts/README.md)
[![DDLC](https://img.shields.io/badge/DDLC-тема_логина-FF80C0?style=for-the-badge&logo=qt&logoColor=white)](https://github.com/rokokol/ddlc-sddm-theme)

Системные сервисы, разложенные по категориям `ai/`, `desktop/`, `devices/`, `system/`, `tools/`, `utils/`. Каждый сервис — отдельный модуль, `default.nix` — единый агрегатор, импортирующий всё на обоих хостах

Общие сервисы включены безусловно, хост-специфичные гейтятся опцией `rokokol.<имя>.enable`, объявленной в своём же модуле. Вход — какие флаги подняты — задаёт `configuration-<host>.nix`, там же и смотри, что где включено: добавить или убрать сервис с хоста значит щёлкнуть флаг там, а не править модуль. Не гейти поведение через `mkIf config.services.foo.enable` из чужого модуля — заводи свою опцию

## Порты и биндинги

Всё биндится на `127.0.0.1`, наружу не торчит ничего — firewall под эти сервисы не открыт. Менять биндинг без причины не надо; если правда нужно выставить наружу — открывай порт явно в том же модуле

| Сервис | Порт |
| --- | --- |
| Ollama | 11434 |
| Open WebUI (ПК; модуль есть, но выключен — фронт переехал в `jan`) | 8088 |
| ComfyUI (ПК) | 8188 |
| SearxNG (ПК, за nginx) | 9000 |
| Jupyter Lab | 8888 |
| LibreTranslate | 5000 |
| Syncthing GUI | 8384 |

Порт объявлен в своём модуле один раз и уходит в `environment.sessionVariables` (`OLLAMA_PORT`, `COMFYUI_PORT`, `OPEN_WEBUI_PORT`, `SYNCTHING_PORT`, `LIBRE_TRANSLATE_PORT`) — скрипты и алиасы берут его оттуда, а не повторяют числом

## Тонкости

- Jupyter везде берёт `pkgs.stable.python3`, а `torch*`/`transformers` доезжают только по `rokokol.jupyter.withTorch` — он поднят на ноуте, где стек ставится бинарниками; на ПК его нет, иначе CUDA-торч собирался бы из исходников
- LibreTranslate стартует на локальных моделях (`updateModels = false`), иначе оффлайн сервис висит до сетевого таймаута. Модели обновляет отдельный юнит `libretranslate-update-models` (недельный таймер, без сети запуск пропускается); вручную — `sudo systemctl start libretranslate-update-models`
- тяжёлые сборки ускоряются кэшами `cuda-maintainers` (объявлен в `nixos/pc/nvidia.nix`) и `comfyui` — при добавлении тяжёлого билда лучше дописать substituter, чем пересобирать
