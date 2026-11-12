---
title: Install the station
kind: guide
---

# Install the station

The station has no checkout. The PC builds its system and deploys later changes over Tailscale SSH. Its installer image contains a snapshot of the station configuration, so rebuild the image after a configuration change you need in the installation

**Installation erases every partition on the configured station disk**. Check `nixos/station/disko.nix`, the disk identity and the station's network configuration before you boot the image. The installer requires UEFI and refuses a machine without that disk, but the identity check is not a substitute for checking your hardware

## Prepare the secrets

The plain image built by Nix contains no secrets. Prepare a private directory outside the repository and the Nix store with the station's age private key as `age-key.txt` and its Tailscale state archive as `tailscale-state.tar`. The archive must contain a top-level `ts-state/` directory with `tailscaled.state` inside. `nix run .#make-station-iso -- help` describes the input and output requirements

Use the station's existing key and a suitable backup of its Tailscale state. Check that the key matches the station recipient in `.sops.yaml` and can decrypt the files the station needs. The installer checks the input format, not that the key can decrypt those files. See [Add a secret](secrets.md) for recipients and host keys

Keep both the prepared directory and its backup private. Do not place a private key, decrypted secret or Tailscale state in the repository or the Nix store

## Build the image

```sh
nix build .#station-installer
nix run .#make-station-iso -- write -s /path/to/private-directory result/iso/*.iso /path/to/private-output.iso
```

Choose an output path outside any Git worktree and outside the Nix store. The output must not exist yet. The resulting ISO contains the age key and Tailscale state: treat the ISO and any copy on a flash drive as secrets

Put the resulting ISO on the boot medium and boot it in UEFI mode. The installer also supports the Ventoy path exercised by `station-install-test`. Check the disk name and size displayed by the installer before allowing the countdown to finish. Press any key during the countdown to stop before the disk is erased

If a preflight check fails, the installer leaves the machine on with a root shell and a log at `/run/station-install.log`. A failure after erasure can leave a partially installed disk. On success, the installer asks you to remove the stick and powers off

## After installation

Boot the station and verify that its Tailscale identity and SSH access work. Check the services you need and the console recovery path before relying on the machine. The station uses its own encrypted secrets file, and its console password must be available through that configuration

Deploy later changes from the PC with the station command in the [repository README](https://github.com/rokokol/huix#commands). Remove the secret-bearing ISO from the computer and the boot medium when it is no longer needed, according to your secret disposal policy

`nix flake check` does not boot the installer. `nix build .#station-install-test -L` runs the installation scenarios in virtual machines; use it after changes to the installer, its disk layout or the installation script
