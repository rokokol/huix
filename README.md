<div align="center">

<img src="./assets/logo.jpg" alt="huix" width="200"/>

# huix

**Мой NixOS-флейк на два хоста — десктоп с NVIDIA/CUDA и ноут, оба на Hyprland** （´ω｀♡%）

![NixOS](https://img.shields.io/badge/NixOS-unstable-5277C3?style=flat&logo=nixos&logoColor=white)
![Nix](https://img.shields.io/badge/Nix-flakes-7EBAE4?style=flat&logo=nixos&logoColor=white)
![Hyprland](https://img.shields.io/badge/WM-Hyprland-00AAAE?style=flat&logo=hyprland&logoColor=white)
![Home Manager](https://img.shields.io/badge/Home_Manager-25.11-41BDF5?style=flat)
![Wayland](https://img.shields.io/badge/session-Wayland-FFBC00?style=flat&logo=wayland&logoColor=black)
![platform](https://img.shields.io/badge/platform-x86__64--linux-1793D1?style=flat&logo=linux&logoColor=white)
[![license](https://img.shields.io/badge/license-MIT-3DA639?style=flat)](LICENSE)

</div>

Короче, это мой конфиг для NixOS — один флейк, два профиля: ПК и ноут. Сижу на Hyprland, юзаю nixvim как IDE, часть штук типа Obsidian, SP или Zen синхронизирую через git/облако, а не декларативно, кривые пакеты тяну через flatpak; рядом крутятся MATLAB/Python/C++

## Карта репозитория

Конфиг разбит на слои, у каждого свой README — путешествуй по кнопкам:

[![nixos](https://img.shields.io/badge/nixos-системный_слой-5277C3?style=for-the-badge&logo=nixos&logoColor=white)](nixos/README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](nixos/services/README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](nixos/fonts/README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](home-manager/README.md)
[![hyprland](https://img.shields.io/badge/hyprland-рабочий_стол-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white)](home-manager/desktop/hyprland/README.md)
[![programs](https://img.shields.io/badge/programs-программы-7E57C2?style=for-the-badge)](home-manager/programs/README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](home-manager/programs/nixvim/README.md)
[![rofi](https://img.shields.io/badge/rofi-лаунчер-EE2A7B?style=for-the-badge)](home-manager/programs/rofi/README.md)
[![scripts](https://img.shields.io/badge/scripts-скрипты-4EAA25?style=for-the-badge&logo=gnubash&logoColor=white)](scripts/README.md)
[![shaders](https://img.shields.io/badge/shaders-эффекты-FF4088?style=for-the-badge&logo=opengl&logoColor=white)](scripts/shaders/README.md)

## Что важно знать

- репо рассчитан на `x86_64-linux` и живёт чисто во flake-workflow, без `nix-channel`/`NIX_PATH`/`<nixpkgs>`
- базовый набор пакетов идёт из `nixos-unstable` (`pkgs`)
- рядом проброшен стабильный `nixos-25.11` как `pkgs.stable` через `overlay-stable`
- на ПК есть CUDA-overlay, дающий `pkgs.cuda.*` — те же пакеты, но собранные с поддержкой CUDA (capability `8.6`). Путать источники нельзя — это триггерит молчаливую пересборку гигантского ML-стека
- Home Manager подключён не отдельным потоком, а как NixOS-модуль с `useGlobalPkgs = true` — системный и пользовательский слой делят один пакетный набор и overlays
- `commonArgs` (`rokokolName`, `huixDir`, `govnoDir`, `system`, `inputs`) пробрасывается и в системные модули через `specialArgs`, и в HM через `extraSpecialArgs` — это единственный способ протащить константы через границу флейка

## Хосты

| Host | Точка входа | Чем выделяется |
| --- | --- | --- |
| `nixos-pc` | `nixos/configuration-pc.nix` + `home-manager/home-pc.nix` | NVIDIA/CUDA, `ollama-cuda`, ComfyUI, Open WebUI, Docker, виртуализация, SearxNG, печать, планшет, Arduino, NTFS-маунт `govno`, Steam, тяжёлый creative-стек |
| `nixos-laptop` | `nixos/configuration-laptop.nix` + `home-manager/home-laptop.nix` | CPU-only `ollama-cpu`, Bluetooth, powertop, Tor через webtunnel, более лёгкий desktop |

## Всякое 

Алиасы: rebuild — обычная сборка, rebuilds — зеркало только от Яндекса, если проблемы с сетью
```sh
rebuild
```

При смене железа:

```sh
sudo nixos-generate-config --show-hardware-config > nixos/<host>/hardware-configuration.nix
```

## Полезные тонкости

- **Ежечасный sync-таймер сам пушит изменения** — `home-manager/desktop/sync.nix` гоняет `scripts/sync.sh`: `pull --rebase` → `add -u` → `commit` → `push`. Из-за `add -u` новый файл без `git add` тихо не уедет в upstream. Пуллься перед правкой на другом хосте
- **`HUIX`** указывает на этот репо и читается скриптами и алиасами — не хардкодь `/home/rokokol/huix`, бери `$HUIX` в скриптах и `huixDir` в Nix
- **Тема свет/тьма — рантайм, не декларатив** — `scripts/toggle_theme.sh` (`SUPER+A`) флипает dconf и пишет выбор в state. Не клади `color-scheme`/`gtk-theme` в HM, иначе `dconf load` на ребилде сбивает выбор
- **Все сервисы биндятся на `127.0.0.1`** — наружу firewall ничего не открывает, см. [таблицу портов](nixos/services/README.md#порты-и-биндинги)
- **`backupFileExtension = "bak-${lastModified}"`** — старые `.bak` копятся в `$HOME` после каждого ребилда с новой ревизии, периодически чисти

## MATLAB

Как-то позволяет скачать матлаб на комп (★^O^★)
```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

## TODO

- [ ] Трайнуть stylix
- [ ] Настроить секреты в sops-nix
- [ ] Настроить disko

<br/>

---

<div align="center">

<img src="./assets/IM%20KING%20OF%20THE%20WORLD!!!.jpg" alt="im king of the world" width="320"/>

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

