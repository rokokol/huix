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

HM подключён не отдельным потоком, а как NixOS-модуль с `useGlobalPkgs = true`, поэтому системный и пользовательский слой делят один пакетный набор и overlays. Важное следствие — `nixpkgs.config` и `nixpkgs.overlays` внутри HM-модуля игнорируются, вся конфигурация пакетов живёт в [`flake.nix`](../flake.nix)

Точка входа — `home-pc.nix` / `home-laptop.nix`: весь вход `rokokol.*` задаётся там, а не в модулях. Дальше пакеты в `desktop/packages/` (общий блок + группы `rokokol.packages.{pc,laptop}`), десктоп в [`desktop/hyprland/`](desktop/hyprland/README.md), тема в `desktop/theme/`, конфиги отдельных программ в [`programs/`](programs/README.md), XDG-директории и env — в `desktop/user.nix`

## Тонкости

- Documents/Pictures/Videos смотрят в `rokokol.home.dataDir` (на ПК это NTFS-раздел `govno`), а волт — в `myWikiDir` из `commonArgs`, одинаковый на обоих хостах: Syncthing везёт симлинки как есть, так что разъехавшиеся пути дали бы битые ссылки на втором хосте
- `home.stateVersion` зафиксирован на `25.11`
- `backupFileExtension = "bak"` в [`flake.nix`](../flake.nix) — фиксированная строка намеренно: суффикс с `lastModified` пересобирал HM-генерацию на каждый коммит и засыпал `$HOME` набором `.bak` на ревизию. Потому коллизия по тому же пути роняет активацию, пока старый `.bak` не удалишь руками
