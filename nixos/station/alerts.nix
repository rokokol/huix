{
  config,
  lib,
  pkgs,
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
# workstation deleted. So does Radicale with btrbk, whose snapshots keep an event that a client
# deleted. The push watch is the only report of a node that went quiet, and
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
    "btrbk-hermes"
    "btrbk-hindsight"
    "btrbk-syncthing"
    "btrfs-scrub@"
    "hermes-agent"
    "hindsight"
    "postgresql"
    "postgresqlBackup-hindsight"
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
    "restic-rest-server"
    "restic-backups-hermes"
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
  };
  home-manager.users.${config.rokokol.mya-agent.user}.rokokol.agents = {
    # The addresses, paths and dashboards come from the modules that own them, so they cannot drift
    skills.station-health = pkgs.runCommand "station-health-skill" { } ''
      install -D -m 0444 ${
        pkgs.replaceVars
          (builtins.path {
            name = "station-health-skill.md";
            path = "${inputs.self}/nixos/services/ai/hermes/skills/station-health/SKILL.md";
          })
          {
            prometheus = "http://127.0.0.1:${toString config.services.prometheus.port}";
            grafana = "http://${config.networking.hostName}:${toString config.rokokol.tailnet-web.sites.grafana.port}";
            dashboards = lib.concatStringsSep ", " config.rokokol.grafana.dashboardTitles;
            alertState = config.rokokol.alert-mail.stateDir;
            localUsers = lib.concatMapStringsSep ", " (
              user: "`${user}`"
            ) config.rokokol.restic-server.localUsers;
          }
      } $out/SKILL.md
    '';
    skillGroups.station-health = "remote";
  };
}
