<div align="center">

<img src="../assets/laptop-wallpaper.png" alt="обои ноута" width="380"/>

<em>тут живёт всё, что делает рабочий стол крутым</em>

</div>

# Home Manager-слой

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![hyprland](https://img.shields.io/badge/hyprland-рабочий_стол-00AAAE?style=for-the-badge&logo=hyprland&logoColor=white)](desktop/hyprland/README.md)
[![programs](https://img.shields.io/badge/programs-программы-7E57C2?style=for-the-badge)](programs/README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](programs/nixvim/README.md)

Всё, что про пользовательское окружение: конфиги приложений, шелл, тема, Hyprland/Waybar, per-user пакеты и systemd-user юниты. Системное (boot, железо, сервисы) — это в [`nixos/`](../nixos/README.md)

HM подключён как NixOS-модуль, поэтому системный и пользовательский слой делят один набор пакетов, а вся настройка пакетов живёт в [`flake.nix`](../flake.nix)

Точка входа — `home-pc.nix` / `home-laptop.nix`: все значения `rokokol.*` задаются там, а не в модулях. Дальше пакеты в `desktop/packages/`, десктоп в [`desktop/hyprland/`](desktop/hyprland/README.md), тема в `desktop/theme/`, конфиги отдельных программ в [`programs/`](programs/README.md), XDG-каталоги и переменные окружения — в `desktop/user.nix`

Волт заметок лежит по одному и тому же пути на обоих хостах: Syncthing возит симлинки как есть, и разные пути дали бы битые ссылки на втором хосте
