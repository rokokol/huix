{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# A Prometheus Pushgateway that the nodes behind the restic server push their metrics to, and a
# check that each of them keeps pushing. The nodes are the users of the restic server's htpasswd,
# so no node name is written here: a node signs in with its restic user and may write only the
# group whose instance label is that user. Prometheus on this host reads the gateway on loopback
let
  cfg = config.rokokol.pushgateway;
  backend = "127.0.0.1:${toString cfg.backendPort}";
  htpasswd = "pushgateway-htpasswd";
  script = builtins.path {
    name = "backup-heartbeat";
    path = "${inputs.self}/scripts/backup-heartbeat.sh";
  };
in
{
  options.rokokol.pushgateway = {
    enable = lib.mkEnableOption "the Pushgateway that the restic nodes push their metrics to";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9091;
      description = "TCP port of the tailnet-web site that the nodes push to";
    };

    backendPort = lib.mkOption {
      type = lib.types.port;
      default = 9191;
      description = "TCP port of the Pushgateway itself, on loopback";
    };

    maxSilence = lib.mkOption {
      type = lib.types.strMatching "[0-9]+[smhd]";
      # The nodes push every 15 minutes, so this allows three missed pushes
      default = "1h";
      description = "Time since the last push of a node past which the node is silent";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.rokokol.restic-server.enable;
        message = "rokokol.pushgateway takes its users from rokokol.restic-server";
      }
      {
        assertion = config.rokokol.prometheus.enable;
        message = "rokokol.pushgateway is read by the Prometheus of this host, which is not enabled";
      }
    ];

    # The restic server's htpasswd again, as a second file that nginx can read. The restic
    # group would also let nginx read the repositories
    sops.secrets.${htpasswd} = {
      key = "restic-server-htpasswd";
      owner = config.services.nginx.user;
      restartUnits = [ "nginx.service" ];
    };

    services.prometheus.pushgateway = {
      enable = true;
      web.listen-address = backend;
      # The last push of each node outlives a restart, or every node would look silent after one
      persistMetrics = true;
    };

    services.prometheus.scrapeConfigs = [
      {
        job_name = "pushgateway";
        # The job and instance labels are the ones the node pushed with, not the gateway's own
        honor_labels = true;
        static_configs = [ { targets = [ backend ]; } ];
      }
    ];

    # A node writes only the group named after itself: PUT, POST or DELETE on
    # /metrics/job/<job>/instance/<user>. Every other path, reads among them, is refused, so no
    # node sees what another one pushed. In `if`, the right side of != takes variables
    rokokol.tailnet-web.sites.pushgateway = {
      inherit (cfg) port;
      backend = "http://${backend}";
      extraConfig = ''
        auth_basic "pushgateway";
        auth_basic_user_file ${config.sops.secrets.${htpasswd}.path};
        limit_except PUT POST DELETE { deny all; }
        set $pushgateway_instance "";
        if ($uri ~ "^/metrics/job/[^/]+/instance/([^/]+)$") {
          set $pushgateway_instance $1;
        }
        if ($pushgateway_instance != $remote_user) {
          return 403;
        }
      '';
    };

    # Reads the gateway's page on loopback, so the check needs the network that the backup
    # heartbeat goes without
    systemd.services.node-push-watch = {
      description = "Check that every node behind the restic server pushed its metrics recently";
      after = [ "pushgateway.service" ];
      path = with pkgs; [
        coreutils
        curl
        gawk
      ];
      # Without pipefail, a gateway that does not answer would pass as an empty page, which
      # names every node as silent instead of the gateway as down
      script = ''
        set -o pipefail
        curl --fail --silent --show-error --max-time 30 http://${backend}/metrics \
          | ${lib.getExe pkgs.bash} ${script} push \
            ${config.services.restic.server.htpasswd-file} ${cfg.maxSilence}
      '';
      serviceConfig = {
        Type = "oneshot";
        DynamicUser = true;
        # The restic group reads the htpasswd, as the backup heartbeat does
        SupplementaryGroups = [ "restic" ];

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        IPAddressAllow = "localhost";
        IPAddressDeny = "any";
        RestrictAddressFamilies = [
          "AF_INET"
          "AF_INET6"
        ];
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
      };
    };

    systemd.timers.node-push-watch = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "*:0/15";
        Persistent = true;
      };
    };
  };
}
