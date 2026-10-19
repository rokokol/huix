{
  config,
  lib,
  pkgs,
  ...
}:

# The receiving end of restic backups that nodes push over the tailnet. Each node has one
# htpasswd user, confined to its repository at /<user>/. The repository key never reaches this
# host, so only the node can forget and prune its own snapshots. A node that deletes what it
# should not cannot reach the read-only snapshots this host takes of every repository. The data
# lives on its own filesystem, and nothing runs or is created while that filesystem is not mounted
let
  cfg = config.rokokol.restic-server;
  unit = "restic-rest-server";
  # btrbk and the disk layout name a subvolume by its path inside the volume
  onVolume = lib.removePrefix "${cfg.mountPoint}/";
  # Both the socket and the service carry them. Without them on the service, a manual start
  # writes to the root filesystem. Without them on the socket, the port accepts a push and fails it
  mountGuard = {
    RequiresMountsFor = [ cfg.dataDir ];
    ConditionPathIsMountPoint = cfg.mountPoint;
  };
in
{
  options.rokokol.restic-server = {
    enable = lib.mkEnableOption "the restic REST server, with daily snapshots of its repositories";

    dataDir = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup/restic";
      description = "Directory of the repositories, on the filesystem mounted at `mountPoint`";
    };

    mountPoint = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup";
      description = "Mountpoint of the backup filesystem; the server does not start without it";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 8000;
      description = "TCP port of the REST server, on every interface";
    };

    snapshotDir = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup/snapshots/restic";
      description = "Directory of the read-only snapshots of `dataDir`, on the same filesystem";
    };

    preserve = lib.mkOption {
      type = lib.types.str;
      default = "14d";
      description = ''
        How long the snapshots of `dataDir` are kept, as btrbk's snapshot_preserve. It is how
        long a backup that a node deleted can still be restored
      '';
    };

    subvolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = map onVolume [
        cfg.dataDir
        cfg.snapshotDir
      ];
      defaultText = lib.literalMD "`dataDir` and `snapshotDir`";
      description = "Subvolumes of the backup filesystem, as paths inside `mountPoint`, for the disk layout to make";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        # btrbk snapshots a subvolume, and the volume's top is not one it can name
        assertion = lib.all (dir: lib.hasPrefix "${cfg.mountPoint}/" dir) [
          cfg.dataDir
          cfg.snapshotDir
        ];
        message = "rokokol.restic-server.dataDir and snapshotDir must be under rokokol.restic-server.mountPoint";
      }
    ];

    # The user names in it are the node names, so the file is a secret. rest-server checks the
    # file for a change only when a request arrives, so the restart applies it at activation
    sops.secrets."restic-server-htpasswd" = {
      owner = "restic";
      group = "restic";
      mode = "0440";
      restartUnits = [ "${unit}.service" ];
    };

    # The firewall stays closed for the port. tailscale.nix beside this file trusts the tailnet
    # interface, and the nodes push only over the tailnet. The LAN stays shut out
    services.restic.server = {
      enable = true;
      inherit (cfg) dataDir;
      listenAddress = toString cfg.port;
      # A node prunes its own repository; the snapshots below keep what it deletes
      appendOnly = false;
      htpasswd-file = config.sops.secrets."restic-server-htpasswd".path;
      prometheus = true;
      # The flag of privateRepos comes through here, because the option also adds a tmpfiles
      # rule for dataDir/.htpasswd. At boot without the backup filesystem, that rule creates
      # dataDir on the root filesystem
      extraFlags = [
        # With private repositories, /metrics admits only an htpasswd user called "metrics".
        # The metrics carry the user names, so the page keeps that password
        "--private-repos"
        # Repositories are 0750 and 0640 under the unit's umask, so the restic group can read
        "--group-accessible-repos"
      ];
    };

    # The upstream module creates the home, which is dataDir, at activation, and activation
    # runs before the backup filesystem is mounted
    users.users.restic.createHome = lib.mkForce false;

    systemd.sockets.${unit} = {
      unitConfig = mountGuard;
      # The disk layout makes dataDir as root's and has no option for an owner. A missing dataDir
      # fails here instead of turning into a plain directory that btrbk cannot snapshot. Not a
      # tmpfiles rule: tmpfiles runs at boot with or without the filesystem. Not on the service: its sandbox binds dataDir for every command it starts, a "+" one too. The
      # service requires the socket, so the socket always starts first
      socketConfig.ExecStartPre = toString (
        pkgs.writeShellScript "restic-data-dir" ''
          set -eu
          PATH=${pkgs.coreutils}/bin
          chown restic:restic ${lib.escapeShellArg cfg.dataDir}
          chmod 0750 ${lib.escapeShellArg cfg.dataDir}
        ''
      );
    };

    systemd.services.${unit}.unitConfig = mountGuard;

    # Once a day, kept for `preserve`. A node that deletes its repository loses at most what it
    # pushed since the last snapshot, and the node still holds that itself
    services.btrbk.instances.restic = {
      onCalendar = "daily";
      settings = {
        timestamp_format = "long";
        snapshot_create = "onchange";
        snapshot_preserve_min = "1d";
        volume.${cfg.mountPoint} = {
          snapshot_dir = onVolume cfg.snapshotDir;
          subvolume.${onVolume cfg.dataDir}.snapshot_preserve = cfg.preserve;
        };
      };
    };

    systemd.services.btrbk-restic.unitConfig = {
      RequiresMountsFor = [
        cfg.dataDir
        cfg.snapshotDir
      ];
      ConditionPathIsMountPoint = cfg.mountPoint;
    };
  };
}
