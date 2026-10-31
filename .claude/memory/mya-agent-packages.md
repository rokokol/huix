---
name: mya-agent-packages
description: Команды Мии задаются в users.users.mya.packages через agent.nix и rokokol.mya-agent.packages, а не в home.packages
metadata:
  node_type: memory
  type: project
  originSessionId: ses_e78ccf2ffffedbXsr0LJRd6xFF
---

Пакеты пользователя `mya` — и агента на станции, и гостевого аккаунта на ПК и ноутбуке — задаются в двух местах:

- базовый список в `nixos/services/ai/hermes/agent.nix` — общий для `cfg.enable` и `cfg.guest.enable`;
- список `rokokol.mya-agent.packages` и `pythonPackages` в `nixos/configuration-station.nix` — только станция, тот же механизм, через который подключены ffmpeg и Python.

Оба списка попадают в `users.users.mya.packages`. `home-manager/home-mya-agent.nix` — это Home Manager-слой (скиллы, MCP, SSH, git, каталоги), а не место для команд агента; `home.packages` там не используется.

`curl` и `jq` уже есть в базовом списке `agent.nix`, поэтому дублировать их в `configuration-station.nix` не нужно. Если команда нужна и гостям, её место в базовом списке; если только станции — в `packages` в `configuration-station.nix`.

Когда открывать: перед добавлением команды для Мии или изменением её профиля.
