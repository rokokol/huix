---
title: Опции rokokol.dav-mcp
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.dav-mcp

<!-- generated: option dav-mcp -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `rokokol.dav-mcp.enable` | да | да | да | Whether to enable the Radicale login for the calendar MCP server. |
| `rokokol.dav-mcp.passwordFile` | `/run/secrets/radicale-password-rokokol` | `/run/secrets/radicale-password-rokokol` | `/run/secrets/radicale-password-mya` | File with the password of `user` in Radicale, readable by that user alone |
| `rokokol.dav-mcp.url` | `http://nixos-station:5232/` | `http://nixos-station:5232/` | `http://127.0.0.1:5233/` | Root URL of the CalDAV server |
| `rokokol.dav-mcp.user` | `rokokol` | `rokokol` | `mya` | Local user whose agents use the calendars, and its login in Radicale |

Объявлено в: `nixos/services/tools/dav-mcp.nix`

<!-- /generated -->
