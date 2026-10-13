{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# An hourly check that every node behind the restic server pushed recently and that the
# backup filesystem keeps its free space. A problem fails the unit, or, with causesFile, goes
# to that file; the host decides what either sets off
let
  cfg = config.rokokol.backup-heartbeat;
  server = config.services.restic.server;
  script = builtins.path {
    name = "backup-heartbeat";
    path = "${inputs.self}/scripts/backup-heartbeat.sh";
  };
  user = "backup-heartbeat";

  # The check writes beside each file before it renames it over the old one
  writable = lib.unique (
    map dirOf (
      lib.filter (file: file != null) [
        cfg.metricsFile
        cfg.causesFile
      ]
    )
  );
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
      default = "/run/${user}/backup.prom";
      description = ''
        File for the newest snapshot time of each repository as Prometheus text metrics, or
        null for none. A tmpfiles rule makes the directory that holds it, owned by the user
        this check runs as, and links the file into the textfile directory of node_exporter
      '';
    };

    causesFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      example = "/run/backup-heartbeat/causes";
      description = ''
        File for the problems as causes, one a line, for an alert registry to read. When set,
        a problem no longer fails the unit: the file carries it, and only a fault of the check
        itself fails it
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

    # The textfile directory is root's, and the check writes beside its file before it renames
    # it over the old one, so the file lives in a directory of its own and is linked
    systemd.tmpfiles.rules =
      map (dir: "d ${dir} 0755 ${user} ${user} -") writable
      ++ lib.optional (
        cfg.metricsFile != null
      ) "L+ ${config.rokokol.node-exporter.textfileDir}/backup.prom - - - - ${cfg.metricsFile}";

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
          ++ lib.optionals (cfg.causesFile != null) [
            "-p"
            cfg.causesFile
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
        ReadWritePaths = writable;
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
