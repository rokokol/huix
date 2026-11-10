---
title: rokokol.dav-mcp options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.dav-mcp options

<!-- generated: option dav-mcp -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.dav-mcp.enable` | yes | yes | yes | Whether to enable the Radicale login for the calendar MCP server. |
| `rokokol.dav-mcp.passwordFile` | `/run/secrets/radicale-password-rokokol` | `/run/secrets/radicale-password-rokokol` | `/run/secrets/radicale-password-mya` | File with the password of `user` in Radicale, readable by that user alone |
| `rokokol.dav-mcp.url` | `http://nixos-station:5232/` | `http://nixos-station:5232/` | `http://127.0.0.1:5233/` | Root URL of the CalDAV server |
| `rokokol.dav-mcp.user` | `rokokol` | `rokokol` | `mya` | Local user whose agents use the calendars, and its login in Radicale |

Declared in: [`nixos/services/tools/dav-mcp.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/dav-mcp.nix)

<!-- /generated -->
