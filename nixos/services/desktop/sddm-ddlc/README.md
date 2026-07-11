# SDDM-тема «DDLC»

Экран логина в стиле Doki Doki Literature Club: белый фон с ползущими по диагонали розовыми кружочками, панель логина в духе меню игры, картинка «Just Monika. OK» как кнопка входа, четыре doki внизу и глитчи при неверном пароле

## Что где

`theme-package.nix` — деривация темы: копирует QML и конвертирует стикеры из `assets/ddlc-stickers` в PNG, потому что Qt6 в greeter не читает webp

`sayori-cursor.nix` — X-курсор из `assets/sddm-cursor`: обычная голова Сайори по умолчанию, глитчнутая — над кликабельными элементами, как менялась иконка в самой игре

`theme/Main.qml` — корень темы: слои, часы, цитата, нижние углы и обработка неверного пароля. Рядом `theme.conf` с палитрой и настройками, а в `components/` лежит по одному компоненту на файл — они в CamelCase, потому что в QML имя файла задаёт имя типа, это сознательное исключение из kebab-case

Подключается всё в `../sddm.nix`: `theme = "ddlc"`, `CursorTheme = "sayori-cursors"`, оба пакета кладутся в `environment.systemPackages`

## Поведение

Девочки внизу дрейфуют влево-вправо, каждая строго в своей полосе — полосы не пересекаются ни между собой, ни с краями экрана, ни с кнопками в нижних углах. При наведении мыши персонаж подпрыгивает и меняет стикер с calm на excited, а изредка подпрыгивает и сам по себе

Неверный пароль запускает глитч примерно на секунду: тряска панели, RGB-split через `QtQuick.Effects`, случайные сканлайны и мигающий искажённый текст

После трёх неверных паролей подряд остаётся одна Моника по центру, остальные растворяются и фон темнеет — Just Monika. Пасхалка сбрасывается успешным входом или минутой тишины

## Ключи theme.conf ([General])

| Ключ | Дефолт | Что делает |
| --- | --- | --- |
| `font` | `Doki` | основной шрифт (из nixos/fonts) |
| `iconFont` | `DepartureMono Nerd Font` | глифы кнопок питания |
| `bgColor` | `#FFF5FA` | цвет фона |
| `accentPink` / `deepPink` | `#FF80C0` / `#D667A0` | рамки и акценты |
| `dotColor` | `#FFDCEE` | цвет кружочков |
| `dotSpacing` / `dotRadius` | `120` / `16` | шаг решётки и радиус кружка |
| `scrollDuration` | `14000` | период дрейфа фона, мс |
| `panelColor` / `panelBorder` | `#FFEBF4` / `#FFBDE1` | панель логина (цвета из игры) |
| `okOutline` | `#BA5297` | обводка кнопки OK |
| `textDark` / `errorRed` | `#4A2B3A` / `#D6244A` | текст и ошибки |
| `glitchRgbSplit` | `true` | выключить, если RGB-split глючит на конкретном железе |

## Оконный тест без выхода из сессии

```sh
nix build .#nixosConfigurations.nixos-laptop.config.system.build.toplevel
theme=$(nix path-info -r ./result | grep sddm-ddlc-theme)
nix shell nixpkgs#sddm -c sddm-greeter-qt6 --test-mode \
  --theme "$theme/share/sddm/themes/ddlc"
```

В test-mode нет демона SDDM, поэтому настоящий `loginFailed` не приходит — для предпросмотра глитча жми F8, три нажатия подряд включают пасхалку
