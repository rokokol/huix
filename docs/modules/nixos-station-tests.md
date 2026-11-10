---
title: nixos/station/tests
kind: module
dir: nixos/station/tests
---

# nixos/station/tests

<!-- generated: module nixos/station/tests -->

## [`nixos/station/tests/boot.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/tests/boot.nix)

The station booted in a VM beside a router and the PC, on demand and not in the flake's
checks: `nix build .#station-boot-test -L`. The station runs its own module list. Only what a
VM cannot have is replaced: the disk layout, the card's MAC, smartd, the secrets, and the
Hindsight bank template, whose import reaches for the models a VM has none of

**Units:** `alert-probe`, `backup-subvolumes`, `fake-github`, `fake-hermes`, `fake-telegram`, `forgejo-mirrors`, `github-echo`, `hindsight-bank-template`, `hindsight-monitor`, `tailnet-web-probe`

## [`nixos/station/tests/fixture-host.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/tests/fixture-host.nix)

What a VM cannot have of the station, replaced in every test that runs it: the card's MAC,
smartd, and the secrets, which come from the fixtures. How the age key gets there is each
test's own question

**Units:** `restic-cloud`, `restic-cloud-heartbeat`

## [`nixos/station/tests/fixtures.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/tests/fixtures.nix)

Only the boot test reaches a GitHub

## [`nixos/station/tests/install.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/tests/install.nix)

The installer image booted in VMs with OVMF, on demand and not in the flake's checks:
`nix build .#station-install-test -L`. One VM installs the station onto a blank SATA disk with
the real disk's model and serial, powers off, and boots from that disk. Others boot the image
where it must refuse, and their disks are compared with blank ones afterwards. The first one
boots it from a stick that Ventoy wrote, up to the countdown. The installed
system is the station with the changes of fixture-host.nix and the test backdoor; the image is
the one the flake builds for that system, with the backdoor too, and its secrets are added by
make-station-iso.sh itself

## [`nixos/station/tests/sops-activation.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/tests/sops-activation.nix)

**Units:** `sops-activation-probe`

## [`nixos/station/tests/test-meta.nix`](https://github.com/rokokol/huix/blob/master/nixos/station/tests/test-meta.nix)

The test's meta declares neither field, and the derivation takes its meta from the option
alone; a second declaration of the submodule adds them

<!-- /generated -->
