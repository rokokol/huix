# huix

Мой репозиторий с конфигурацией NixOS и Home Manager для ПК и ноутбука

## Что внутри
- `flake.nix` / `flake.lock`: входная точка и закреплённые зависимости
- `nixos/`: системные модули NixOS, включая хост‑конфиги и сервисы
- `home-manager/`: пользовательские конфиги (Hyprland, nixvim, оболочка и пр.)
- `logo.jpg`, `wallpaper_*.png`: локальные ассеты

## Быстрый старт
Сборка и применение:
```sh
sudo nixos-rebuild switch --flake .#nixos-pc
sudo nixos-rebuild switch --flake .#nixos-laptop
```

Также в дальнейшем есть аллиас `rebuild`

Обновление входов флейка:
```sh
nix flake update
```

## Структура конфигов
- `nixos/configuration-pc.nix`, `nixos/configuration-laptop.nix` — верхнеуровневые хост‑конфиги
- `nixos/pc/` и `nixos/laptop/` — хост‑специфичные модули
- `nixos/services/` — сервисы (searxng, docker, jupyter и т.д.)
- `home-manager/home-*.nix` — пользовательские entrypoints

## Дерево проекта
```
.
├── flake.nix
├── flake.lock
├── nixos
│   ├── configuration-pc.nix
│   ├── configuration-laptop.nix
│   ├── pc
│   │   ├── boot.nix
│   │   ├── desktop.nix
│   │   ├── hardware.nix
│   │   ├── hardware-configuration.nix
│   │   ├── nvidia.nix
│   │   ├── packages.nix
│   │   ├── sound.nix
│   │   └── system.nix
│   ├── laptop
│   │   ├── boot.nix
│   │   ├── desktop.nix
│   │   ├── hardware.nix
│   │   ├── hardware-configuration.nix
│   │   ├── packages.nix
│   │   └── system.nix
│   ├── services
│   │   ├── amnezia-vpn.nix
│   │   ├── arduino.nix
│   │   ├── cachix.nix
│   │   ├── docker.nix
│   │   ├── jupyter.nix
│   │   ├── nix-ld.nix
│   │   ├── ollama.nix
│   │   ├── openwebui.nix
│   │   ├── printing.nix
│   │   ├── searxng.nix
│   │   ├── sddm.nix
│   │   ├── ssh-askpass.nix
│   │   ├── syncting.nix
│   │   ├── tablet.nix
│   │   ├── virtualization.nix
│   │   └── wl-clip-persist.nix
│   └── fonts
│       ├── fonts.nix
│       └── *.otf/*.ttf
├── home-manager
│   ├── home-pc.nix
│   ├── home-laptop.nix
│   ├── desktop
│   │   ├── dconf.nix
│   │   ├── user-pc.nix
│   │   └── user-laptop.nix
│   ├── hyprland
│   │   ├── hyprland.conf
│   │   ├── hypridle.nix
│   │   ├── hyprland-*.nix
│   │   ├── waybar-*.nix
│   │   ├── systemd.nix
│   │   ├── cursor.nix
│   │   └── scripts
│   │       └── *.sh
│   └── programs
│       ├── zsh.nix
│       ├── kitty.nix
│       ├── ssh.nix
│       ├── starship.nix
│       ├── btop*.nix
│       ├── git.nix
│       ├── nixvim
│       │   ├── nixvim.nix
│       │   ├── settings.nix
│       │   ├── keymaps.nix
│       │   └── plugins
│       │       └── *.nix
│       └── neovim.nix
├── AGENTS.md
├── README.md
├── LICENSE
├── logo.jpg
└── wallpaper_*.png
```

## Примечания
Перед сборкой архижелательно обновлять `hardware-configuration.nix`:
```sh
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix
```

Каким-то образом это качает MATLAB:
```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

---

![Текущее лого](./logo.jpg)


- [x] Сделать нормальное разделение по файлам
- [x] Разобраться с видеокартой
- [x] Подтягивать пакеты из stable и unstable отдельно
- [X] Сделать конфигурационный файл для того, чтобы можно было без проблем портировать на свой ноутбук систему
- [x] Настроить работу с дровами моего компа
- [x] Сделать себе нормлаьный терминал
- [x] Наконец-то навести порядок в конфиге nvim
- [x] Перейти на nixvim или [это](https://www.youtube.com/watch?v=uP9jDrRvAwM)
  - https://www.youtube.com/watch?v=VTIGSxpzlIM
- [ ] Попробовать stylix
- ~~Полностью декларативно настроить Gnome~~
  - [ ] ~~Night Light~~
  - [ ] ~~Папки на десктопе~~
  - [ ] ~~..?~~
- [ ] Декларативно настроить разметку диска
- [ ] Распределить музыку по плейлистам
- [x] Перейти на btfrs
- [x] Попробовать hyprland
- [x] Декларативно настроить SearXNG
- [ ] Починить в nixvim картинки в телескопе
- [ ] Вынести секреты в что-то типа soapsnix

