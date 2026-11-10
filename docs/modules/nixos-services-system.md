---
title: nixos/services/system
kind: module
dir: nixos/services/system
---

# nixos/services/system

<!-- generated: module nixos/services/system -->

## [`nixos/services/system/appimage.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/appimage.nix)

binfmt_misc lets *.AppImage run directly without unpacking
steam-run wraps any binary in a full FHS sandbox (/usr, /lib, real ld.so) for prebuilts
that nix-ld can't satisfy

**Options:** `rokokol.appimage.enable`

More: [rokokol.appimage options](../options/appimage.md)

## [`nixos/services/system/cachix.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/cachix.nix)

The tunnel's IPv6 route to Yandex's AS resets the TLS handshake (other IPv6 hosts work
fine); pin IPv4 to skip it

## [`nixos/services/system/envfs.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/envfs.nix)

envfs serves /bin and /usr/bin from the PATH of the calling process, so a script or a plugin
that hardcodes /bin/bash or /usr/bin/python3 finds the binary instead of failing with ENOENT

**Options:** `rokokol.envfs.enable`

More: [rokokol.envfs options](../options/envfs.md)

## [`nixos/services/system/nix-ld.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/nix-ld.nix)

nix-ld makes non-Nix prebuilt binaries find their shared libs via NIX_LD instead of dying
with "No such file or directory"

**Options:** `rokokol.nix-ld.enable`

More: [rokokol.nix-ld options](../options/nix-ld.md)

## [`nixos/services/system/restic-server.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/restic-server.nix)

The receiving end of restic backups that nodes push over the tailnet. Each node has one
htpasswd user, confined to its repository at /<user>/. The repository key never reaches this
host, so only the node can forget and prune its own snapshots. A node that deletes what it
should not cannot reach the read-only snapshots this host takes of every repository. The data
lives on its own filesystem, and nothing runs or is created while that filesystem is not mounted

**Options:** `rokokol.restic-server.dataDir`, `rokokol.restic-server.enable`, `rokokol.restic-server.localUserName`, `rokokol.restic-server.localUsers`, `rokokol.restic-server.mountPoint`, `rokokol.restic-server.port`, `rokokol.restic-server.preserve`, `rokokol.restic-server.snapshotDir`, `rokokol.restic-server.subvolumes`

More: [rokokol.restic-server options](../options/restic-server.md)

**Units:** `btrbk-restic`, `restic-backups-station`

## [`nixos/services/system/skvpn.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/skvpn.nix)

The seam for rokokol/skvpn: enable plus the routing policy. The module already owns the
CLI with its completions, the sing-box@ template unit, boot restore, the subscription
sync timer, the sing-box user, the profiles directory, the loose rpfilter and the
TUN/DNS base — including the bypasses for Tailscale, Docker and Syncthing, which follow
their services.*.enable by themselves, and the Russia and AI rule-set data, which lives
in the module's own lock and refreshes with the weekly input bump. Do not add any of
that back here

## [`nixos/services/system/sops.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/sops.nix)

sops-nix only decrypts at activation, through its own sops-install-secrets binary — it puts
nothing on PATH. Editing a file in secrets/ needs the CLIs

## [`nixos/services/system/tailnet-web.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/tailnet-web.nix)

Web services of this host, published to the tailnet with one port each. nginx is the one
listener: a backend binds to loopback or a socket, and a site here forwards a port to it. The
firewall opens none of the ports, because tailscale.nix beside this file trusts the tailnet
interface. nginx also refuses every address outside the tailnet ranges, so a port that the
firewall opens by mistake still serves nothing to the LAN. A site that sets `lan` is the
exception: the firewall opens its port on the LAN link, and nginx admits the LAN network. There is
no enable option: a service that declares a site is published, and its own option gates it

**Options:** `rokokol.tailnet-web.lan`, `rokokol.tailnet-web.sites`

More: [rokokol.tailnet-web options](../options/tailnet-web.md)

## [`nixos/services/system/tailscale.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/tailscale.nix)

Mesh client for the official Tailscale coordination server. The tailnet is joined once by
hand (`sudo tailscale up`) — the state lives in /var/lib/tailscale and survives rebuilds

## [`nixos/services/system/zram.nix`](https://github.com/rokokol/huix/blob/master/nixos/services/system/zram.nix)

Swap compressed in RAM, used only under memory pressure: it holds cold pages in place of an OOM
kill. Its priority is above a disk swap's default, so the laptop's partition takes only what
zram cannot. A default, so a host can stay without swap.

Swap metrics count the pages zram holds at their full size, which says nothing of the RAM it
takes. mm_stat has both, and a timer writes them for node_exporter wherever zram is on

**Units:** `zram-metrics`

<!-- /generated -->
