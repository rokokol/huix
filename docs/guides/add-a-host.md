---
title: Add a host
kind: guide
---

# Add a host

Each host has a NixOS configuration and a Home Manager configuration. `lib/mk-host.nix` joins them into one system, and `flake.nix` supplies the overlays for that host

This flake currently selects one system architecture for every host in `flake.nix`. A host with another architecture needs a change to that shared design first

## Describe the hardware

Generate a hardware configuration on the new machine and review the result before you add it under `nixos/<host>/`. If you use disko for its filesystems, do not also declare those filesystems in the generated file; see `nixos/station/hardware-configuration.nix` and `nixos/station/disko.nix`

Create a host directory and an entry point under `nixos/configuration-<host>.nix`. Use an existing host as a starting point, but review its hardware, network, service flags and storage before you copy them. Set `networking.hostName` for the new machine and choose `system.stateVersion` for its installation rather than changing an existing host's value

## Add the home and register the host

Create `home-manager/home-<host>.nix` and pass both entry points to `mkHost` in `flake.nix`. Choose the overlays the new host needs. `pkgs.stable` is available only where the host selects the stable overlay

For a graphical host, set `rokokol.workstation.enable` in its NixOS configuration. Desktop modules default to that switch, while a headless host leaves it disabled. Select other services with their own `rokokol.*.enable` options

## Prepare access and secrets

Give the host access to the secrets its enabled modules require before activation. Follow [Add a secret](secrets.md) for the age keys, encrypted files and module declarations. In particular, Syncthing derives its key and certificate names from `networking.hostName`; configure the new device identity and its secrets if that service is enabled

Review network addresses, SSH access, firewall rules and references to existing host names. Do not assume that every service discovers a new host automatically

## Evaluate and build

```sh
nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath
nix run .#docs-build
nix flake check
nix build .#nixosConfigurations.<host>.config.system.build.toplevel
```

The renderer updates existing generated blocks. The current strict build refuses a missing host or option page, so create the required page and its generated marker before running `docs-build`. Review generated changes before you commit them. `nix flake check` evaluates hosts and builds its checks, but it does not build each host's system closure; the last command checks that separately

Deploy only after the target's disk, access and secrets are ready. A remote host such as the station needs a reachable target and a separate deployment path; see [Install the station](install-station.md)
