---
title: rokokol.mail-agent options
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# rokokol.mail-agent options

<!-- generated: option mail-agent -->

| Option | nixos-laptop | nixos-pc | nixos-station | Description |
| --- | --- | --- | --- | --- |
| `rokokol.mail-agent.enable` | no | yes | yes | Whether to enable the mail agent service. |
| `rokokol.mail-agent.socketUser` | `rokokol` | `rokokol` | `mya` | Who may talk to the socket, and so whose agents get the skill |

Declared in: [`nixos/services/tools/mail-agent.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/tools/mail-agent.nix)

<!-- /generated -->
