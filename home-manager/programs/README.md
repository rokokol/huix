<div align="center">

<img src="../../assets/say-sketch2.webp" alt="say sketch" width="280"/>

</div>

# Программы

[![huix](https://img.shields.io/badge/huix-наверх-222222?style=for-the-badge&logo=nixos&logoColor=white)](../../README.md)
[![home-manager](https://img.shields.io/badge/home--manager-юзер_слой-5E81AC?style=for-the-badge)](../README.md)
[![nixvim](https://img.shields.io/badge/nixvim-neovim-019733?style=for-the-badge&logo=neovim&logoColor=white)](nixvim/README.md)
[![yazi](https://img.shields.io/badge/yazi-файлы-FFC107?style=for-the-badge)](yazi/README.md)

Тут собраны программы, которые делают пользовательскую среду удобнее и подстраиваются под привычный рабочий процесс

Среди них — редактор [Nixvim](nixvim/README.md), файловый менеджер [Yazi](yazi/README.md), командные утилиты и графические приложения

ИИ-агенты — Claude Code и OpenCode — получают MCP-серверы и скиллы из общих списков. Сервер и скилл объявляются один раз рядом со своим инструментом, и их сразу видят все агенты, а руками ничего регистрировать не нужно. Так подключены календарь, поиск статей, Ghidra и сам OpenCode, а скилл приходит той же версии, что и его сервер. Скиллы из собственных репозиториев приходят flake inputs'ами, и каждый хост берёт из них только нужные

В Claude Code инструменты распределены по отключаемым плагинам: `huix` для разработки и системной конфигурации, `reversing` для реверс-инжиниринга, `research` для статей и документации, `creative` для видео, звука и 3D, `remote` для связи и управления устройствами. Плагин отключается вместе со своими скиллами и MCP, например через `claude plugin disable creative@inline`; после изменения перечитай плагины или начни новую сессию. OpenCode получает тот же набор под прежними именами, а настройки плагинов Claude Code на него не влияют

В `reversing/` собраны Ghidra с ReVa и REA с собственным MCP и скиллом исследования приложений. REA использует Ghidra для headless-анализа и также исследует поддерживаемые форматы без запуска графического редактора

Творческие приложения собраны в `creative/`: Kdenlive с MCP и скиллами Anatomy, Remotion и sound-layer, Blender с MCP, Audacity с MCP и FreeCAD с MCP. Редактор видео позволяет продолжить ручной монтаж после работы агента, а звуковые инструменты подбирают эффекты, сводят дорожки и проверяют результат

Некоторые инструменты выросли в отдельные проекты; ссылки на них найдёшь в корневом [README](../../README.md#вынесено-в-отдельные-репо)
