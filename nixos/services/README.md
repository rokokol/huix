<div align="center">

<img src="../../assets/sayori-v-korobke.jpg" alt="каждый сервис в своей коробочке" width="300"/>

<em>каждый сервис разложен аккуратно по своей коробочке</em>

</div>

# Сервисы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](../fonts/README.md)
[![DDLC](https://img.shields.io/badge/DDLC-тема_логина-FF80C0?style=for-the-badge&logo=qt&logoColor=white)](https://github.com/rokokol/ddlc-sddm-theme)

Системные сервисы, разложенные по категориям `ai/`, `desktop/`, `devices/`, `system/`, `tools/`, `utils/`. Каждый сервис — отдельный модуль, а `default.nix` подключает их все на обоих хостах

Общие сервисы включены всегда, а те, что нужны только одному хосту, включаются флагом `rokokol.<имя>.enable` в `configuration-<host>.nix`. Добавить или убрать сервис с хоста — значит переключить флаг там, а не править модуль

## Сеть

Все сервисы слушают только `127.0.0.1`, и firewall для них закрыт. Порт каждого объявлен один раз в его модуле и доступен скриптам как переменная окружения. Снаружи хост доступен только через Tailscale: sshd принимает соединения лишь из тайлнета, а кто из нод куда может ходить, решает политика тайлнета, а не huix

## Сервисы

- **ИИ и инструменты** — Ollama, SearxNG, LibreTranslate. LibreTranslate работает офлайн на локальных моделях и обновляет их сам раз в неделю, когда есть сеть. ComfyUI, Open WebUI и Jupyter ставятся докером: их пакеты в nixpkgs тянут несогласованный CUDA-стек и долгие пересборки
- **Tailscale** — хост заводится в тайлнет вручную один раз (`sudo tailscale up`) и дальше живёт без ключей в конфиге
- **VPN** — [skvpn](https://github.com/rokokol/skvpn), переключение профилей без sudo (`skvpn up <профиль>`), российские сайты идут мимо туннеля
- **Диски** — `smartd` проверяет все диски по расписанию, короткими и длинными тестами, пропущенный тест догоняет после пробуждения, а о проблеме сообщает уведомлением на рабочий стол
- **Датчики** (ноутбук) — акселерометр для автоповорота экрана в режиме планшета. После первого включения нужна перезагрузка, а не перелогин
- **Syncthing** — синхронизация волта заметок между хостами
