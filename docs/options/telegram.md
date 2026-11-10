---
title: Опции rokokol.telegram
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.telegram

<!-- generated: option telegram -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `alert-mail.telegram.api` | `https://api.telegram.org` | `https://api.telegram.org` | `https://api.telegram.org` | Base URL of the Telegram Bot API |
| `alert-mail.telegram.enable` | нет | нет | да | Whether to enable a copy of each alert in the owner's Telegram, through the bot whose token and the
owner's chat id are the sops secrets telegram-bot-token and telegram-owner-chat-id
. |
| `alert-mail.telegram.threadId` | — | — | `1089071` | Topic of the forum in the owner's chat that carries the alerts, passed as the Bot API's
`message_thread_id`, which the API accepts for forum supergroups alone. A message sent
without it reaches the chat's General topic, while the agent's own replies go to the
topic its gateway is configured with
 |

Объявлено в: `nixos/services/system/monitoring/alert-mail.nix`

<!-- /generated -->
