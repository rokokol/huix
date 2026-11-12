---
title: Add a system service
kind: guide
---

# Add a system service

A service is one module in `nixos/services/<category>/`, an import in the aggregator, an option of its own and a flag in the host that wants it. Nothing is switched on anywhere else

## Where the file goes

Pick the category that matches what the service touches: `ai/`, `desktop/`, `devices/`, `system/`, `tools/`, `utils/`. The file is kebab-case and named after the service

Add the path to `nixos/services/default.nix`. That list is imported by every host, so a new module reaches the station as well unless it gates itself

## The module

Declare the option in the module that acts on it, and gate the configuration with the same option:

```nix
{
  config,
  lib,
  ...
}:

{
  options.rokokol.thing.enable = lib.mkEnableOption "the thing" // {
    default = config.rokokol.workstation.enable;
  };

  config = lib.mkIf config.rokokol.thing.enable {
    services.thing.enable = true;
  };
}
```

A desktop-only module defaults its flag to `rokokol.workstation.enable`, so the workstations get it and the headless station does not. The station's own services default to `false` and name the host that turns them on

Do not reach for `config.services.foo.enable` from another module: the flag of this repository is the switch, and a second way to turn the same thing on is a second source of truth

## Turning it on

Add the flag to `nixos/configuration-<host>.nix`:

```nix
rokokol.thing.enable = true;
```

A service on `127.0.0.1` needs nothing more. A web service that the other hosts should reach stays on loopback and declares a site in `rokokol.tailnet-web.sites`, which publishes it to the tailnet alone

## The check

Make new files visible to Git before you evaluate the flake; an untracked module is not included in a Git-backed flake source. The strict renderer refuses a missing page, so create the required option or module page with its generated marker first. Then generate and review the documentation and run the checks:

```sh
nix run .#docs-build
nix flake check
```

If the service needs credentials, follow [Add a secret](secrets.md). Deploy only after the target host and its access are ready; the station uses the remote command in the [repository README](https://github.com/rokokol/huix#commands)

To inspect derivation changes against a chosen revision, run the comparison below. It exits nonzero when paths change, which is expected for a new service:

```sh
nix run .#drv-diff -- -r HEAD~1
```
