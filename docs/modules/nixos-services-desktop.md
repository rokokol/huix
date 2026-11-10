---
title: Модули nixos/services/desktop
kind: module
---

# Модули nixos/services/desktop

<!-- generated: module nixos/services/desktop -->

## `nixos/services/desktop/amnezia-vpn.nix`

**Опции:** `rokokol.amnezia-vpn.enable`

Подробнее: [опции rokokol.amnezia-vpn](../options/amnezia-vpn.md)

## `nixos/services/desktop/file-manager.nix`

**Опции:** `rokokol.file-manager.enable`

Подробнее: [опции rokokol.file-manager](../options/file-manager.md)

## `nixos/services/desktop/flatpak.nix`

nix-flatpak installs what services.flatpak.packages lists and removes what leaves the list.
uninstallUnmanaged stays off, so an app installed by hand stays installed

**Опции:** `rokokol.flatpak.enable`

Подробнее: [опции rokokol.flatpak](../options/flatpak.md)

## `nixos/services/desktop/gnome-keyring.nix`

Secret Service for libsecret clients — Geary keeps its IMAP passwords here and refuses to
store them without one. The module wires pam_gnome_keyring into "login", which SDDM's own
PAM stack substacks, so the keyring unlocks with the login password and never prompts

**Опции:** `rokokol.gnome-keyring.enable`

Подробнее: [опции rokokol.gnome-keyring](../options/gnome-keyring.md)

## `nixos/services/desktop/molvai.nix`

The daemon reads its OpenRouter key from the environment, so sops renders it into a file that
only the owner can read. The secret itself is the same key Pi uses

**Опции:** `rokokol.molvai.enable`

Подробнее: [опции rokokol.molvai](../options/molvai.md)

## `nixos/services/desktop/sddm.nix`

Theme, cursors and the QML-cache workaround come from the module

**Опции:** `rokokol.sddm.enable`

Подробнее: [опции rokokol.sddm](../options/sddm.md)

## `nixos/services/desktop/ssh-agent.nix`

gcr's agent instead of OpenSSH's: it keeps key passphrases in the keyring from
gnome-keyring.nix and asks through its own GTK prompt, so a passphrase is typed once ever
instead of once per boot. Only one agent may own SSH_AUTH_SOCK, so programs.ssh.startAgent
stays off — an assertion in the gcr module enforces that

**Опции:** `rokokol.ssh-agent.enable`

Подробнее: [опции rokokol.ssh-agent](../options/ssh-agent.md)

<!-- /generated -->
