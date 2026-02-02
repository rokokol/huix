# huix
My NixOS config ☠️☠️
![Текущее лого](./logo.jpg)


- [x] Сделать нормальное разделение по файлам
- [x] Разобраться с видеокартой
- [ ] Подтягивать пакеты из stable и unstable отдельно
- [ ] Сделать конфигурационный файл для того, чтобы можно было без проблем портировать на свой ноутбук систему
- [x] Настроить работу с дровами моего компа
- [x] Сделать себе нормлаьный терминал
- [ ] Наконец-то навести порядок в конфиге nvim
- [ ] Перейти на nixvim или [это](https://www.youtube.com/watch?v=uP9jDrRvAwM)
  - https://www.youtube.com/watch?v=VTIGSxpzlIM
- [ ] Попробовать stylix
- Полностью декларативно настроить Gnome
  - [ ] Night Light
  - [ ] Папки на десктопе
  - [ ] ..?
- [ ] Декларативно настроить разметку диска
- [ ] Распределить музыку по плейлистам
- [x] Перейти на btfrs
- [ ] Попробовать hyprland


Каким-то образом это качает MATLAB:
```sh
nix run gitlab:doronbehar/nix-matlab#matlab-shell
nix shell gitlab:doronbehar/nix-matlab#matlab --command /run/media/rokokol/MATHWORKS_R2025A/install
```

Перед каждой сборкой архижелательно обновлять `hardware-configuration.nix`:
```
sudo nixos-generate-config --show-hardware-config > hardware-configuration.nix 
```

---

![Текущие темные обои](./wallpaper_dark.png)
![Текущие светлые обои](./wallpaper_light.png)

