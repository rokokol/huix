<div align="center">

<img src="./assets/logo.jpg" alt="huix" width="200"/>

# huix

**Мой NixOS-флейк на два хоста — десктоп с NVIDIA/CUDA и ноут, оба на Hyprland** （´ω｀♡%）

![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat&logo=nixos&logoColor=white)
![Nix](https://img.shields.io/badge/Nix-flakes-7EBAE4?style=flat&logo=nixos&logoColor=white)
![Hyprland](https://img.shields.io/badge/WM-Hyprland-00AAAE?style=flat&logo=hyprland&logoColor=white)
![platform](https://img.shields.io/badge/platform-x86__64--linux-1793D1?style=flat&logo=linux&logoColor=white)
[![license](https://img.shields.io/badge/license-MIT-3DA639?style=flat)](LICENSE)
[![eval](https://github.com/rokokol/huix/actions/workflows/eval.yml/badge.svg)](https://github.com/rokokol/huix/actions/workflows/eval.yml)

</div>

Короче, это мой конфиг для NixOS. Сижу на Hyprland, юзаю nixvim как IDE, часть штук типа Obsidian, SP или Zen синхронизирую через git/облако, а не декларативно, кривые пакеты тяну через flatpak; рядом крутятся MATLAB/Python/C++

## Команды

```sh
sudo nixos-rebuild switch --flake .#nixos-pc   # или .#nixos-laptop
rebuild                                        # алиас на то же для текущего хоста
rebuilds                                       # то же, но пакеты с зеркала Яндекса — если проблемы с сетью
```

При смене железа:

```sh
sudo nixos-generate-config --show-hardware-config > nixos/<host>/hardware-configuration.nix
```

Матлаб (как-то позволяет скачать матлаб на комп (★^O^★)):

```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

## Хосты

| Host | Точка входа | Чем выделяется |
| --- | --- | --- |
| `nixos-pc` | `nixos/configuration-pc.nix` + `home-manager/home-pc.nix` | NVIDIA/CUDA, `ollama-cuda`, ComfyUI, SearxNG, виртуализация, печать, планшет, виртуальная камера, Steam, тяжёлый creative-стек, NTFS-маунт `govno` |
| `nixos-laptop` | `nixos/configuration-laptop.nix` + `home-manager/home-laptop.nix` | CPU-only `ollama-cpu` и Jupyter с CPU-торчем, Bluetooth, powertop, батарея и подсветка в баре, тумблер "крышка не усыпляет" |

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

Куски, которые переросли конфиг и живут своими флейками — huix подключает их входами и держит по одному шву на каждый. Вся семья вместе с самим конфигом помечена топиком [huix](https://github.com/topics/huix), так что список ниже есть кому пересчитать и без README:

[![screen-shader](https://img.shields.io/badge/screen--shader-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](https://github.com/rokokol/hyprland-screen-shader)
[![claude-account](https://img.shields.io/badge/claude--account-профили_Claude-D97757?style=for-the-badge&logo=anthropic&logoColor=white)](https://github.com/rokokol/claude-account)
[![rofi-wooordhunt](https://img.shields.io/badge/rofi--wooordhunt-словарь-F4A100?style=for-the-badge)](https://github.com/rokokol/rofi-wooordhunt)
[![virtual-media-devices](https://img.shields.io/badge/virtual--media--devices-камера_и_микрофон-2E9E9E?style=for-the-badge&logo=ffmpeg&logoColor=white)](https://github.com/rokokol/virtual-media-devices)
[![ddlc-palette](https://img.shields.io/badge/ddlc--palette-цвета-BB5599?style=for-the-badge)](https://github.com/rokokol/ddlc-palette)
[![ddlc-sddm-theme](https://img.shields.io/badge/ddlc--sddm--theme-экран_логина-FF80C0?style=for-the-badge&logo=qt&logoColor=white)](https://github.com/rokokol/ddlc-sddm-theme)
[![ddlc-hyprlock](https://img.shields.io/badge/ddlc--hyprlock-локскрин-58E1FF?style=for-the-badge)](https://github.com/rokokol/ddlc-hyprlock)
[![ddlc-rofi-theme](https://img.shields.io/badge/ddlc--rofi--theme-тема_rofi-EE2A7B?style=for-the-badge)](https://github.com/rokokol/ddlc-rofi-theme)
[![ddlc.nvim](https://img.shields.io/badge/ddlc.nvim-тема_редактора-76C332?style=for-the-badge&logo=neovim&logoColor=white)](https://github.com/rokokol/ddlc.nvim)
[![ddlc-terminal-themes](https://img.shields.io/badge/ddlc--terminal--themes-kitty_и_btop-72D0FA?style=for-the-badge)](https://github.com/rokokol/ddlc-terminal-themes)

## Что стоит знать

- `SUPER+A` переключает свет/тьму на лету — тема выбирается в рантайме и переживает ребилд, декларативно она нигде не прибита
- цвета тут не выбираются вообще: [ddlc-palette](https://github.com/rokokol/ddlc-palette) снимает их с ddlc.moe и отдаёт готовыми, темы приложений приезжают собранными из своих репо. Хекс в модуле — повод спросить, почему он не оттуда
- все сервисы биндятся на `127.0.0.1`, наружу firewall не открывает ничего — [таблица портов](nixos/services/README.md#порты-и-биндинги)
- MIT покрывает только код. Шрифт `Doki` принадлежит Team Salvato и лежит тут как фан-контент, курсор — работа sev; условия по каждому файлу — в [ASSETS.md](ASSETS.md). Проект не аффилирован с Team Salvato и ими не одобрен

> [!WARNING]
> Секреты идут через sops-nix, и age-ключа (`~/.config/sops/age/keys.txt`) в репо нет. На новом хосте его надо положить туда руками до первого ребилда, иначе активация упадёт

## TODO

- [ ] Трайнуть stylix
- [ ] Настроить disko

<br/>

---

<div align="center">

<img src="./assets/im-king-of-the-world.jpg" alt="im king of the world" width="320"/>

<br/><br/>

<table>
<tr><td align="center">

❄️❄️🚀 <b>ВСЕ ВАШИ ПАКЕТНИКИ ГОВНО</b> 🤬❄️<br/>
МУТАБЕЛЬНЫЙ МУСОР 🌋🚀❄️ НУЖНО ПЕРЕЙТИ ❄️ НА НИКС ❄️❤️<br/>
😍 НА НИКС ПЕРЕЙДИ ❄️❄️<br/>
НА НИКС ПЕРЕЙДИ СУКА 😡❄️<br/>
🚀 МНЕ НУЖНА ❄️❄️ ДЕКЛАРАТИВНОСТЬ СУКА 🚀❄️<br/>
ДЕКЛАРАТИВНЫЙ НИКС ПОДХОД 😍❤️🚀❄️<br/>
ВСЕ ВАШИ ОС ИМПЕРАТИВНОЕ 🤬💩 ГОВНО ❄️<br/>
❄️ ПЕРЕЙДИ НА НИКС

</td></tr>
</table>

<a href="https://никспобеда.рф"><img src="https://img.shields.io/badge/никспобеда.рф-❄️_НИКС_ПОБЕДА-1793D1?style=for-the-badge&logo=nixos&logoColor=white" alt="никспобеда.рф"/></a>

<sub>❄️ made with declarative love · NixOS ❄️</sub>

</div>
