---
title: nixos/services/desktop
kind: module
dir: nixos/services/desktop
---

# nixos/services/desktop

<!-- generated: module nixos/services/desktop -->

## [`nixos/services/desktop/amnezia-vpn.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/desktop/amnezia-vpn.nix)

**Options:** `rokokol.amnezia-vpn.enable`

More: [rokokol.amnezia-vpn options](../options/amnezia-vpn.md)

## [`nixos/services/desktop/file-manager.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/desktop/file-manager.nix)

**Options:** `rokokol.file-manager.enable`

More: [rokokol.file-manager options](../options/file-manager.md)

## [`nixos/services/desktop/flatpak.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/desktop/flatpak.nix)

nix-flatpak installs what services.flatpak.packages lists and removes what leaves the list.
uninstallUnmanaged stays off, so an app installed by hand stays installed

**Options:** `rokokol.flatpak.enable`

More: [rokokol.flatpak options](../options/flatpak.md)

## [`nixos/services/desktop/gnome-keyring.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/desktop/gnome-keyring.nix)

Secret Service for libsecret clients — Geary keeps its IMAP passwords here and refuses to
store them without one. The module wires pam_gnome_keyring into "login", which SDDM's own
PAM stack substacks, so the keyring unlocks with the login password and never prompts

**Options:** `rokokol.gnome-keyring.enable`

More: [rokokol.gnome-keyring options](../options/gnome-keyring.md)

## [`nixos/services/desktop/molvai.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/desktop/molvai.nix)

The daemon reads its OpenRouter key from the environment, so sops renders it into a file that
only the owner can read. The secret itself is the same key Pi uses

**Options:** `rokokol.molvai.enable`

More: [rokokol.molvai options](../options/molvai.md)

## [`nixos/services/desktop/sddm.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/desktop/sddm.nix)

Theme, cursors and the QML-cache workaround come from the module

**Options:** `rokokol.sddm.enable`

More: [rokokol.sddm options](../options/sddm.md)

## [`nixos/services/desktop/ssh-agent.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/desktop/ssh-agent.nix)

gcr's agent instead of OpenSSH's: it keeps key passphrases in the keyring from
gnome-keyring.nix and asks through its own GTK prompt, so a passphrase is typed once ever
instead of once per boot. Only one agent may own SSH_AUTH_SOCK, so programs.ssh.startAgent
stays off — an assertion in the gcr module enforces that

**Options:** `rokokol.ssh-agent.enable`

More: [rokokol.ssh-agent options](../options/ssh-agent.md)

<!-- /generated -->
