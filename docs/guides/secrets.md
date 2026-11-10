---
title: Add a secret
kind: guide
---

# Add a secret

A secret is decrypted at activation from a file the store never holds in clear, and a module asks for it by name. Which file it lands in decides which hosts can read it, and that choice is the whole of the work

## Which file

`.sops.yaml` routes a path to a set of age keys, and the first rule that matches wins. The desktops share the owner's key. The station has a key of its own, since it holds the backups of the other machines and must not read their secrets

- A secret that only a workstation needs goes into `secrets/secrets.yaml`
- A secret the station needs goes into `secrets/station.yaml`, which is encrypted to the station's key as well
- A secret both sides share, such as the mailbox or the Telegram application credentials, goes into the file whose rule names both

An entry in the desktops' file that the station's configuration also asks for fails the station's build with a missing key, and that failure is the point: the station cannot read it whatever the configuration says

## The entry

Edit the file through sops so the value is encrypted in place, and give it the name the module will use:

```sh
sops secrets/station.yaml
```

A binary or a JSON file, such as the Drive client of `drive-backup`, stays a file of its own and gets a rule of its own

## Asking for it

```nix
sops.secrets.thing-token = {
  owner = rokokolName;
  mode = "0400";
};
```

The file appears at `config.sops.secrets.<name>.path`, and that path is what a unit reads. A service that takes the value in its environment gets it from `config.sops.placeholder.<name>`, which expands to the path rather than to the value, so the value never enters a derivation

## What a page may say

Names and paths are ordinary facts and belong in the configuration. A value never does: not in a comment, not in a page of this documentation, not in an example. The corpus lists the names of the secrets of each host for that reason
