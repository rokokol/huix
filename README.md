<div align="center">

<img src="./assets/logo.jpg" alt="huix" width="200"/>

# huix

**Мой NixOS-флейк — десктоп с NVIDIA/CUDA и ноут на Hyprland плюс домашний сервер без экрана** （´ω｀♡%）

![NixOS](https://img.shields.io/badge/NixOS-system-5277C3?style=flat&logo=nixos&logoColor=white)
![Nix](https://img.shields.io/badge/Nix-flakes-7EBAE4?style=flat&logo=nixos&logoColor=white)
![Hyprland](https://img.shields.io/badge/WM-Hyprland-00AAAE?style=flat&logo=hyprland&logoColor=white)
[![assets](https://img.shields.io/badge/assets-third--party-FF80C0?style=flat)](ASSETS.md)
[![workarounds](https://img.shields.io/badge/docs-workarounds-555?style=flat)](WORKAROUNDS.md)
[![deviations](https://img.shields.io/badge/docs-deviations-555?style=flat)](DEVIATIONS.md)
[![license](https://img.shields.io/badge/license-MIT-3DA639?style=flat)](LICENSE)
[![eval](https://github.com/rokokol/huix/actions/workflows/eval.yml/badge.svg)](https://github.com/rokokol/huix/actions/workflows/eval.yml)

</div>

Короче, это мой NixOS для рабочего ПК, ноутбука и домашнего сервера: Hyprland, nixvim и куча приложений для повседневных дел. Часть программ я держу отдельно от конфига, а для всего остального стараюсь собрать удобную среду под себя

## Команды

```sh
sudo nixos-rebuild switch --flake .#nixos-pc   # или .#nixos-laptop
rebuild                                        # алиас на то же для текущего хоста
rebuilds                                       # то же, но пакеты с зеркала Яндекса — если проблемы с сетью
```

Станция своего чекаута не держит: её собирает ПК и заливает по Tailscale SSH

```sh
nixos-rebuild switch --flake .#nixos-station --target-host rokokol@nixos-station --sudo --ask-sudo-password
nix build .#station-boot-test -L      # станция в виртуалках рядом с роутером и ПК, только по запросу
nix build .#station-install-test -L   # её установочный образ в виртуалках: отказы и полная установка
```

Первый раз станция ставится с флешки: образ без секретов собирает `nix build .#station-installer`, секреты в копию добавляет `nix run .#make-station-iso -- write result/iso/*.iso OUTPUT`, и этот OUTPUT после установки удаляют. Что станция умеет — в [описании системного слоя](nixos/README.md#станция)

Если поменялось железо, обнови его описание:

```sh
sudo nixos-generate-config --show-hardware-config > nixos/<host>/hardware-configuration.nix
```

Матлаб тоже можно запустить через Nix (★^O^★):

```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

## Хосты

| Хост | Назначение |
| ---- | ---------- |
| Рабочий ПК | Рабочий хост для разработки и творческих задач |
| Ноутбук-трансформер | Рабочий хост с сенсорным экраном, пером и режимом планшета |
| Домашний сервер | Хранит резервные копии, собирает состояние хостов и предоставляет домашние службы |

## Карта репозитория

Конфиг разбит на слои, у каждого свой README:

[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](nixos/README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](nixos/services/README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](nixos/fonts/README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](home-manager/README.md)
[![hyprland](https://img.shields.io/badge/hyprland-рабочий_стол-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white)](home-manager/desktop/hyprland/README.md)
[![programs](https://img.shields.io/badge/programs-программы-7E57C2?style=for-the-badge)](home-manager/programs/README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](home-manager/programs/nixvim/README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](scripts/README.md)

## Вынесено в отдельные репо

Куски, которые переросли конфиг и живут своими флейками — huix подключает их входами и держит по одному шву на каждый. Вся семья вместе с самим конфигом помечена топиком [huix](https://github.com/topics/huix)

[![screen-shader](https://img.shields.io/badge/screen--shader-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)
[![claude-account](https://img.shields.io/badge/claude--account-профили_Claude-D97757?style=for-the-badge&logo=anthropic&logoColor=white)](https://github.com/rokokol/claude-account)
[![rofi-wooordhunt](https://img.shields.io/badge/rofi--wooordhunt-словарь-F4A100?style=for-the-badge)](https://github.com/rokokol/rofi-wooordhunt)
[![virtual-media-devices](https://img.shields.io/badge/virtual--media--devices-камера_и_микрофон-2E9E9E?style=for-the-badge&logo=ffmpeg&logoColor=white)](https://github.com/rokokol/virtual-media-devices)
[![skvpn](https://img.shields.io/badge/skvpn-VPN--клиент-2B5797?style=for-the-badge&logo=python&logoColor=white)](https://github.com/rokokol/skvpn)
[![ddlc-palette](https://img.shields.io/badge/ddlc--palette-цвета-BB5599?style=for-the-badge)](https://github.com/rokokol/ddlc-palette)
[![ddlc-sddm-theme](https://img.shields.io/badge/ddlc--sddm--theme-экран_логина-FF80C0?style=for-the-badge&logo=qt&logoColor=white)](https://github.com/rokokol/ddlc-sddm-theme)
[![ddlc-hyprlock](https://img.shields.io/badge/ddlc--hyprlock-локскрин-58E1FF?style=for-the-badge)](https://github.com/rokokol/ddlc-hyprlock)
[![ddlc-rofi-theme](https://img.shields.io/badge/ddlc--rofi--theme-тема_rofi-EE2A7B?style=for-the-badge)](https://github.com/rokokol/ddlc-rofi-theme)
[![ddlc.nvim](https://img.shields.io/badge/ddlc.nvim-тема_редактора-76C332?style=for-the-badge&logo=neovim&logoColor=white)](https://github.com/rokokol/ddlc.nvim)
[![ddlc-themes](https://img.shields.io/badge/ddlc--themes-kitty_и_btop-72D0FA?style=for-the-badge)](https://github.com/rokokol/ddlc-themes)

## Пара заметок

- Светлую и тёмную темы можно переключать на лету — выбор переживает перезагрузки и пересборки
- О том, что крутится на машинах, читай в [системном слое](nixos/README.md) и разделе [служб](nixos/services/README.md)

<br/>

---

<div align="center">

<img src="./assets/felix.png" alt="Felix Argail" width="480"/>

<em>an average nixos user :3</em>

<br/>

<table>
<tr><td align="center">

❄️❄️🚀 <b>ВСЕ ВАШИ ПАКЕТНИКИ ГОВНО</b> 🤬❄️<br/> МУТАБЕЛЬНЫЙ МУСОР 🌋🚀❄️ НУЖНО ПЕРЕЙТИ ❄️ НА НИКС ❄️❤️<br/> 😍 НА НИКС ПЕРЕЙДИ ❄️❄️<br/> НА НИКС ПЕРЕЙДИ СУКА 😡❄️<br/> 🚀 МНЕ НУЖНА ❄️❄️ ДЕКЛАРАТИВНОСТЬ СУКА 🚀❄️<br/> ДЕКЛАРАТИВНЫЙ НИКС ПОДХОД 😍❤️🚀❄️<br/> ВСЕ ВАШИ ОС ИМПЕРАТИВНОЕ 🤬💩 ГОВНО ❄️<br/> ❄️ ПЕРЕЙДИ НА НИКС

</td></tr>
</table>

<a href="https://никспобеда.рф"><img src="https://img.shields.io/badge/никспобеда.рф-❄️_НИКС_ПОБЕДА-1793D1?style=for-the-badge&logo=nixos&logoColor=white" alt="никспобеда.рф"/></a>

<sub>❄️ made with declarative love · NixOS ❄️</sub>

</div>
