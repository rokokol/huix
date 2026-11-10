---
title: Опции rokokol.guest
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.guest

<!-- generated: option guest -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `mya-agent.guest.enable` | да | да | нет | Whether to enable the session's user without the session, for the agent on another host to log in to over
SSH. It reaches no service on this host's loopback but the resolver and `loopbackPorts`,
since such a service trusts every local user, and of the owner's files only `shares`
. |
| `mya-agent.guest.loopbackPorts` |  |  |  | TCP ports on this host's loopback that the session's user still reaches, by the name of
what listens there
 |
| `mya-agent.guest.owner` | `rokokol` | `rokokol` | — | The user whose directories `shares` show to the session's user |
| `mya-agent.guest.power.enable` | да | да | нет | Whether to enable the units that let the guest put this host to sleep, lock it and turn it off. |
| `mya-agent.guest.shares` | `Documents=path=/home/rokokol/Documents`, `writable=да`, `Downloads=path=/home/rokokol/Downloads`, `writable=да`, `Pocket=path=/home/rokokol/Pocket`, `writable=да`, `Projects=path=/home/rokokol/Projects`, `writable=нет` | `Documents=path=/home/rokokol/Documents`, `writable=да`, `Downloads=path=/home/rokokol/Downloads`, `writable=да`, `Pocket=path=/home/rokokol/Pocket`, `writable=да`, `Projects=path=/home/rokokol/Projects`, `writable=нет` |  | The owner's directories the session's user sees, by the path under its home. A share it
only reads shows what any other user may read there, so a file only the owner may read
stays closed. In a writable share every file looks like the session user's own, and a
file it makes is the owner's on disk. The rest of the owner's home stays out of reach
 |

Объявлено в: `nixos/services/ai/hermes/agent.nix`, `nixos/services/ai/hermes/power.nix`

<!-- /generated -->
