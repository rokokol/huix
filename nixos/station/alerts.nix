{
  config,
  lib,
  inputs,
  ...
}:

# The units whose failure mails root through alert-mail@. Each one fails where nothing else would
# say so: the heartbeat is the only report of a missed backup or a missing backup volume, the
# receiver and its socket are what the nodes push to, a scrub is the only report of a rotten
# block (disko.nix names the two units' filesystems), smartd is the only watch on the disk, and
# tailscaled with its flag-setting unit is the only shell into this host. The Telegram agent
# fails only when its session keeps ending at once; then the bot is silent. Forgejo, its nightly
# dump, the units that make the owner's account and register the runners, and the mirror run
# fail with no one looking. So do Prometheus, whose failure is a hole in the history found only
# later, and Grafana, and Syncthing with btrbk, whose archive and its snapshots keep what a
# workstation deleted. So does Radicale with its data unit and btrbk, whose snapshots keep an
# event that a client deleted. The push watch is the only report of a node that went quiet, and
# the Pushgateway is what the nodes push to. The exporters and the zram timer are left out: an empty
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
    "btrbk-radicale"
    "btrbk-restic"
    "btrbk-syncthing"
    "btrfs-scrub@"
    "mya-agent"
    "forgejo"
    "forgejo-dump"
    "forgejo-mirrors"
    "forgejo-owner"
    "forgejo-runners"
    "grafana"
    "node-push-watch"
    "prometheus"
    "pushgateway"
    "radicale"
    "radicale-data"
    "restic-rest-server"
    "smartd"
    "syncthing"
    "tailscaled"
    "tailscaled-set"
  ];

  systemd.sockets = onFailure [ "restic-rest-server" ];

  # Telegram is the channel that does not pass through the mail node, so an alert about that
  # node still arrives. The agent gets each alert too, to act on it at once
  rokokol.alert-mail = {
    telegram.enable = true;
    inherit (config.rokokol.mya-agent) notify;
    # Each repository, each node and each problem a node reports is an alert of its own, so a
    # second silent node is sent even while the first is still open
    sources = {
      backup = config.rokokol.backup-heartbeat.causesFile;
      node = config.rokokol.pushgateway.causesFile;
    };
  };
  rokokol.backup-heartbeat.causesFile = "/run/backup-heartbeat/causes";
  rokokol.pushgateway.causesFile = "/run/node-push-watch/causes";

  # The agent reads the open problems, the metrics and the journal of every unit through its
  # station-health plugin. The journal of the whole host reaches the model's context that way,
  # which the owner accepts
  rokokol.mya-agent = {
    extraGroups = [ "systemd-journal" ];
    plugins = [
      (builtins.path {
        name = "station-health-plugin";
        path = "${inputs.self}/nixos/services/ai/mya-agent/plugins/station-health";
      })
    ];
  };
}
