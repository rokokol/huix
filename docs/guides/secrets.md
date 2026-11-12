---
title: Add a secret
kind: guide
---

# Add a secret

SOPS encrypts the files in `secrets/`. During activation, sops-nix decrypts each declared secret into a protected file on the host. The encrypted source can enter the Nix store; the plaintext must not enter a Nix expression, a derivation, a log or a commit

## Choose the file and recipients

Run SOPS from the repository root, where `.sops.yaml` maps file paths to age recipients. The first matching rule wins. Check both the rule and the module's `sopsFile` before you add a value

- Workstations use `secrets/secrets.yaml` by default, and the station uses `secrets/station.yaml` by default
- The station file is encrypted to both the owner and the station. A workstation can use an entry from it when its module explicitly selects that file
- Mail, Telegram, Hindsight and Drive have separate files and rules. Their modules select those files explicitly
- The general YAML rule grants access only to the owner. Do not assume that a new YAML file is readable by the station

A host needs a matching private key to decrypt its selected file. The hosts read `/var/lib/sops-nix/key.txt`; the station has its own key. Back up the private keys securely and keep them out of the repository and the store

## Add a value

Make sure the SOPS CLI can access the owner's age key. For a non-default location, set `SOPS_AGE_KEY_FILE` to the private key file in your shell. Edit the selected encrypted file with SOPS:

```sh
sops secrets/station.yaml
```

Add a YAML key and its value in the editor, then save and close it. Do not put real values into shell commands, examples or screenshots. SOPS writes the encrypted file back to the repository

For a new file or recipient, inspect `.sops.yaml` first. Add a specific rule before the general rule if necessary, then create the file with SOPS. When recipients change, `sops updatekeys secrets/<file>` updates the recipients of an existing file; confirm the change only after you have verified the intended public keys and retained access to a private key that can decrypt it

## Declare and use it

Declare the secret in the NixOS module that needs it. With no `sopsFile`, the host's default file supplies the entry:

```nix
sops.secrets.thing-token = {
  owner = rokokolName;
  mode = "0400";
};
```

The module must accept `rokokolName` as an argument. Pass `config.sops.secrets.thing-token.path` to a service that reads a file. Set `sopsFile` when the entry lives elsewhere, and set `key` when its name inside that file differs from the declared name. See `nixos/services/tools/dav-mcp.nix` for a file override

For an entire encrypted JSON file, select `format = "json"` and `key = ""`; `nixos/services/tools/drive-backup.nix` shows the full declaration. A different format or path also needs a matching SOPS rule

For a service that needs an environment file, use `sops.templates`: `config.sops.placeholder.<name>` is a marker in the template content, not a file path. At activation, sops-nix replaces it with the decrypted value and writes the protected template file. Pass `config.sops.templates.<template>.path` to the consumer; see `nixos/services/tools/paper-search.nix`

Choose ownership and permissions for the consumer. If a changed secret must restart a service, declare the appropriate `restartUnits` on that secret. Secrets needed before user creation require `neededForUsers = true`; `nixos/station/system.nix` shows the password case

## Check and deploy

1. Review the encrypted diff and ensure no plaintext or private key is staged. Check that each host's selected file contains the declared key and that its age recipient can decrypt it
2. Evaluate the affected host and run `nix flake check`. A missing key in a selected file can fail evaluation, but successful evaluation alone does not prove that the host's private key can decrypt it
3. If the station needs a new secret, update the relevant test fixtures under `nixos/station/tests/` without putting real values there. Build the station VM test when the change affects what the station imports
4. Run `nix run .#docs-build` if the declared secret names changed, and review the generated pages. The host pages list declarations, not every key in every encrypted file
5. Deploy to the target host through its normal rebuild procedure. The station has no checkout: the PC builds and deploys it over Tailscale
6. On the target, check that the expected secret file exists and has the intended owner and permissions. Check the consuming service without printing the secret. Verify separately that the service has picked up a changed value

For station installation and the handling of its private key, see [Install the station](install-station.md)
