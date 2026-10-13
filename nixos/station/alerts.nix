{ lib, ... }:

# The units whose failure mails root through alert-mail@. Each one fails where nothing else would
# say so: the heartbeat is the only report of a missed backup or a missing backup volume, the
# receiver and its socket are what the nodes push to, a scrub is the only report of a rotten
# block (disko.nix names the two units' filesystems), smartd is the only watch on the disk, and
# tailscaled with its flag-setting unit is the only shell into this host. Forgejo, its nightly
# dump, the units that make the owner's account and register the runners, and the mirror run
# fail with no one looking. So do Prometheus, whose failure is a hole in the history found only
# later, and Grafana, and Syncthing with btrbk, whose archive and its snapshots keep what a
# workstation deleted. The push watch is the only report of a node that went quiet, and the
# Pushgateway is what the nodes push to. The exporters and the zram timer are left out: an empty
# panel shows their failure, and a timer that fails each half minute would flood the mailbox. A
# unit that fails with the link down is left out, as the mail could not leave either
let
  onFailure =
    names:
    lib.genAttrs names (_: {
      unitConfig.OnFailure = "alert-mail@%n.service";
    });
in
{
  systemd.services = onFailure [
    "backup-heartbeat"
    "btrbk-syncthing"
    "btrfs-scrub@"
    "forgejo"
    "forgejo-dump"
    "forgejo-mirrors"
    "forgejo-owner"
    "forgejo-runners"
    "grafana"
    "node-push-watch"
    "prometheus"
    "pushgateway"
    "restic-rest-server"
    "smartd"
    "syncthing"
    "tailscaled"
    "tailscaled-set"
  ];

  systemd.sockets = onFailure [ "restic-rest-server" ];
}
