{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# An hourly check that every node behind the restic server pushed recently and that the
# backup filesystem keeps its free space. A problem fails the unit and nothing more: the host
# decides what the failure sets off, through OnFailure on this service
let
  cfg = config.rokokol.backup-heartbeat;
  server = config.services.restic.server;
  script = builtins.path {
    name = "backup-heartbeat";
    path = "${inputs.self}/scripts/backup-heartbeat.sh";
  };
  user = "backup-heartbeat";
in
{
  options.rokokol.backup-heartbeat = {
    enable = lib.mkEnableOption "the watchdog over the restic server's repositories";

    maxAge = lib.mkOption {
      type = lib.types.strMatching "[0-9]+[smhd]";
      # The nodes push once a day, so this allows one missed push and some delay
      default = "36h";
      description = "Age of the newest snapshot past which a repository is stale";
    };

    minFree = lib.mkOption {
      type = lib.types.strMatching "[0-9]+[KMGT]?";
      default = "10G";
      description = "Free space the backup filesystem must keep, in powers of 1024";
    };

    metricsFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/var/lib/prometheus-node-exporter-text-files/backup.prom";
      description = ''
        File for the newest snapshot time of each repository as Prometheus text metrics,
        read by a node_exporter textfile collector. A tmpfiles rule makes the directory
        that holds it, owned by the user this check runs as
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.rokokol.restic-server.enable;
        message = "rokokol.backup-heartbeat reads the repositories of rokokol.restic-server";
      }
    ];

    # The restic group reads the repositories, which rest-server writes group-readable, and
    # the htpasswd secret; it cannot write either
    users.users.${user} = {
      isSystemUser = true;
      group = user;
      extraGroups = [ "restic" ];
    };
    users.groups.${user} = { };

    systemd.tmpfiles.rules = lib.optional (
      cfg.metricsFile != null
    ) "d ${dirOf cfg.metricsFile} 0755 ${user} ${user} -";

    # No mount dependency and no mount condition: without the filesystem, the check runs and
    # its output names the missing data. A condition would skip the check in silence
    systemd.services.backup-heartbeat = {
      description = "Check that every restic repository got a recent snapshot";
      path = with pkgs; [
        coreutils
        findutils
        gawk
      ];
      serviceConfig = {
        Type = "oneshot";
        User = user;
        Group = user;
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe pkgs.bash)
            script
            "check"
          ]
          ++ lib.optionals (cfg.metricsFile != null) [
            "-m"
            cfg.metricsFile
          ]
          ++ [
            server.dataDir
            server.htpasswd-file
            cfg.maxAge
            cfg.minFree
          ]
        );

        CapabilityBoundingSet = "";
        LockPersonality = true;
        MemoryDenyWriteExecute = true;
        NoNewPrivileges = true;
        PrivateDevices = true;
        PrivateNetwork = true;
        PrivateTmp = true;
        ProtectHome = true;
        ProtectKernelModules = true;
        ProtectKernelTunables = true;
        ProtectSystem = "strict";
        ReadWritePaths = lib.optional (cfg.metricsFile != null) (dirOf cfg.metricsFile);
        RestrictAddressFamilies = "none";
        SystemCallArchitectures = "native";
        SystemCallFilter = "@system-service";
      };
    };

    systemd.timers.backup-heartbeat = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "hourly";
        # An hour missed while the host was off is checked at the next boot
        Persistent = true;
      };
    };
  };
}
