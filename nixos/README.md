# NixOS-слой

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../README.md)
[![services](https://img.shields.io/badge/services-сервисы-0E7C7B?style=for-the-badge)](services/README.md)
[![fonts](https://img.shields.io/badge/fonts-шрифты-EA4AAA?style=for-the-badge&logo=googlefonts&logoColor=white)](fonts/README.md)

Здесь всё, что касается самой системы: железо, загрузка, сеть и службы. Приложения и настройки рабочего стола живут в [Home Manager](../home-manager/README.md)

Состав системы подстроен под каждую машину. О службах и шрифтах можно почитать отдельно: [службы](services/README.md), [шрифты](fonts/README.md)

Рабочая среда доступна на настольном ПК и ноутбуке, а сервер остаётся без графического окружения

## Станция

Станция — домашний сервер без экрана: бережёт резервные копии, присматривает за службами и пишет, если что-то важное сломалось. А когда нужен мощный ПК — может его разбудить

С флешки станцию можно установить даже без сети. Команды сборки образа и проверки установки собраны в [корневом README](../README.md#команды)
