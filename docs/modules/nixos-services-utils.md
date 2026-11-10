---
title: nixos/services/utils
kind: module
dir: nixos/services/utils
---

# nixos/services/utils

<!-- generated: module nixos/services/utils -->

## [`nixos/services/utils/docker.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/utils/docker.nix)

**Опции:** `rokokol.docker.enable`

Подробнее: [опции rokokol.docker](../options/docker.md)

## [`nixos/services/utils/embedded.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/utils/embedded.nix)

Embedded toolchain for Arduino/AVR, ESP32, STM32, RP2040
platformio-core.udev ships udev rules for common programmers/bootloaders; dialout grants
/dev/ttyUSB* /dev/ttyACM* access

**Опции:** `rokokol.embedded.enable`

Подробнее: [опции rokokol.embedded](../options/embedded.md)

## [`nixos/services/utils/forgejo-runner.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/utils/forgejo-runner.nix)

A Forgejo Actions runner that takes jobs from the station and runs each in a Docker container.
The runner trusts no workflow: it has only docker:// labels, so no job runs on this host, and
its container settings hold whatever a workflow asks for. A job gets no Docker socket, no
privileged mode and no volume of this host; the runner drops --privileged, --cap-add, --device
and the host network from a job's container options on its own. Jobs run one at a time and
give way to the desktop when the CPU is busy. The runner itself can reach the root Docker
daemon, so a flaw in the runner, not in a job, is what this setup trusts

**Опции:** `rokokol.forgejo-runner.enable`, `rokokol.forgejo-runner.labels`, `rokokol.forgejo-runner.name`, `rokokol.forgejo-runner.secretsFile`, `rokokol.forgejo-runner.unit`, `rokokol.forgejo-runner.url`

Подробнее: [опции rokokol.forgejo-runner](../options/forgejo-runner.md)

## [`nixos/services/utils/virtualization.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/utils/virtualization.nix)

**Опции:** `rokokol.virtualization.enable`

Подробнее: [опции rokokol.virtualization](../options/virtualization.md)

**Юниты:** `virt-secret-init-encryption`

<!-- /generated -->
