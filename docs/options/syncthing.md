---
title: Опции rokokol.syncthing
kind: option
hosts: [nixos-laptop, nixos-pc, nixos-station]
---

# Опции rokokol.syncthing

<!-- generated: option syncthing -->

| Опция | nixos-laptop | nixos-pc | nixos-station | Описание |
| --- | --- | --- | --- | --- |
| `syncthing.deviceId` | `IACQG6Z-QHUKT7Y-EZXPKTH-BIT3LJR-BCXTRV6-FZZK3LB-SUKSHBR-UG44GAM` | `MNSJ7QK-4YOWUOS-3O5MSOT-UXON7VW-PZFY2YC-34MDG2H-UHTWJ7H-QLTDKQV` | `6CQJLFE-TE77FII-NTQQIOX-XKDOALI-WFDZU4D-SJLMJ62-MUMN5S4-KSPMJQV` | This host's device ID, as its Syncthing shows it; the other hosts trust it |
| `syncthing.enable` | да | да | да | Whether to enable Syncthing between the workstations, the phone and the archive. |
| `syncthing.keyFromSops` | да | да | да | Whether to enable the device's key and certificate from the sops secrets syncthing-key-<host> and
syncthing-cert-<host>, in the host's default sops file
. |

Объявлено в: `nixos/services/tools/syncthing.nix`

<!-- /generated -->
