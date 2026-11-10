---
title: nixos/services/ai/hermes
kind: module
dir: nixos/services/ai/hermes
---

# nixos/services/ai/hermes

<!-- generated: module nixos/services/ai/hermes -->

## [`nixos/services/ai/hermes/agent.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/agent.nix)

The agent and its remote guest accounts share one identity and repository sync policy

**Опции:** `rokokol.mya-agent.directories`, `rokokol.mya-agent.enable`, `rokokol.mya-agent.extraGroups`, `rokokol.mya-agent.git.email`, `rokokol.mya-agent.git.name`, `rokokol.mya-agent.guest.enable`, `rokokol.mya-agent.guest.loopbackPorts`, `rokokol.mya-agent.guest.owner`, `rokokol.mya-agent.guest.shares`, `rokokol.mya-agent.hiddenPaths`, `rokokol.mya-agent.home`, `rokokol.mya-agent.packages`, `rokokol.mya-agent.pythonPackages`, `rokokol.mya-agent.repositories`, `rokokol.mya-agent.syncUnit`, `rokokol.mya-agent.syncedBy`, `rokokol.mya-agent.user`

Подробнее: [опции rokokol.mya-agent](../options/mya-agent.md)

**Юниты:** `mya-agent-clone`

## [`nixos/services/ai/hermes/backup.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/backup.nix)

Hermes makes consistent SQLite copies, and the station's own restic backup takes the archive

**Опции:** `rokokol.mya-agent.hermes.backup.dataDir`, `rokokol.mya-agent.hermes.backup.enable`, `rokokol.mya-agent.hermes.backup.mountPoint`, `rokokol.mya-agent.hermes.backup.subvolumes`

Подробнее: [опции rokokol.mya-agent](../options/mya-agent.md)

**Юниты:** `hermes-agent`, `hermes-backend`, `hermes-backup-zip`, `hermes-state`, `restic-backups-station`

## [`nixos/services/ai/hermes/default.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/default.nix)

## [`nixos/services/ai/hermes/gigaam.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/gigaam.nix)

## [`nixos/services/ai/hermes/github.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/github.nix)

GitHub for the agent without a token in its session. gh in the session talks to nginx through
a Unix socket, and nginx sets the token by the path of each request: the classic token for what
a fine-grained token cannot reach, and the read-only one for everything else. Text that the
session reads can make it ask the proxy for an allowed request, but no request shows a token

**Опции:** `rokokol.mya-agent.github.api`, `rokokol.mya-agent.github.enable`, `rokokol.mya-agent.github.socket`

Подробнее: [опции rokokol.mya-agent](../options/mya-agent.md)

## [`nixos/services/ai/hermes/hermes.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/hermes.nix)

Nix owns service boundaries; Hermes owns its memory, skills and scheduled prompts

**Опции:** `rokokol.mya-agent.hermes.cronTopic`, `rokokol.mya-agent.hermes.dashboardAutoStart`, `rokokol.mya-agent.hermes.dashboardPort`, `rokokol.mya-agent.hermes.homeTopic`, `rokokol.mya-agent.hermes.memoryMax`, `rokokol.mya-agent.hermes.reportsTopic`, `rokokol.mya-agent.hermes.webhookPort`, `rokokol.mya-agent.notify`

Подробнее: [опции rokokol.mya-agent](../options/mya-agent.md)

**Юниты:** `hermes-agent`, `hermes-backend`, `hermes-hindsight-settings`

## [`nixos/services/ai/hermes/hindsight-plugin.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/hindsight-plugin.nix)

The Hindsight memory provider is a catalog plugin, not part of the Hermes tree.
Its source is the Vectorize integration shipped beside the Hindsight server, and the
provider imports the generated Python client from the same checkout.

## [`nixos/services/ai/hermes/monitor.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/monitor.nix)

A timer collects local usage without a permanent exporter process

**Опции:** `rokokol.mya-agent.hermes.monitor.api`, `rokokol.mya-agent.hermes.monitor.enable`, `rokokol.mya-agent.hermes.monitor.lowBalance`

Подробнее: [опции rokokol.mya-agent](../options/mya-agent.md)

**Юниты:** `hermes-monitor`

## [`nixos/services/ai/hermes/power.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/ai/hermes/power.nix)

The agent puts a workstation to sleep, locks it, darkens its screen, turns it off or restarts
it. Its guest user there may start one unit for each of these and nothing else; the units run
as root, and the screen's as the owner, whose Hyprland it is

**Опции:** `rokokol.mya-agent.guest.power.enable`, `rokokol.mya-agent.power.enable`

Подробнее: [опции rokokol.mya-agent](../options/mya-agent.md)

<!-- /generated -->
