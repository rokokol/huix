{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.rokokol.hindsight;
  inherit (cfg) backup;
  onVolume = lib.removePrefix "${backup.mountPoint}/";
  guard = {
    RequiresMountsFor = [ backup.dumpDir ];
    ConditionPathIsMountPoint = backup.mountPoint;
  };
in
{
  options.rokokol.hindsight.backup = {
    mountPoint = lib.mkOption {
      type = lib.types.str;
      description = "Mountpoint of the backup volume";
    };
    dumpDir = lib.mkOption {
      type = lib.types.str;
      description = "Subvolume holding consistent PostgreSQL dumps";
    };
    snapshotDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory of PostgreSQL dump snapshots";
    };
    subvolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = lib.optionals cfg.enable (
        map onVolume [
          cfg.dataDir
          backup.dumpDir
          backup.snapshotDir
        ]
      );
      defaultText = lib.literalMD "Hindsight data, dump and snapshot subvolumes when enabled";
      description = "Subvolumes for the disk layout to create";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (lib.hasPrefix "${backup.mountPoint}/") [
          cfg.dataDir
          backup.dumpDir
          backup.snapshotDir
        ];
        message = "Hindsight data, dumps and snapshots must be under the backup mountpoint";
      }
    ];
    services.postgresqlBackup = {
      enable = true;
      databases = [ "hindsight" ];
      location = backup.dumpDir;
      compression = "zstd";
      pgdumpOptions = "--format=custom --compress=0 --no-owner --no-acl";
      startAt = "*-*-* 02:30:00";
    };
    systemd.services.postgresqlBackup-hindsight = {
      unitConfig = guard;
      serviceConfig.UMask = "0077";
      serviceConfig.User = "postgres";
      serviceConfig.Group = "postgres";
      serviceConfig.ExecStartPre = [
        "+${pkgs.coreutils}/bin/install -d -m 700 -o postgres -g postgres ${backup.dumpDir}"
        "+${pkgs.btrfs-progs}/bin/btrfs subvolume show ${backup.dumpDir}"
      ];
    };
    services.btrbk.instances.hindsight = {
      onCalendar = "*-*-* 03:00:00";
      settings = {
        timestamp_format = "long";
        snapshot_create = "onchange";
        snapshot_preserve_min = "1d";
        volume.${backup.mountPoint} = {
          snapshot_dir = onVolume backup.snapshotDir;
          subvolume.${onVolume backup.dumpDir}.snapshot_preserve = "14d 8w";
        };
      };
    };
    systemd.services.btrbk-hindsight = {
      unitConfig = guard;
      requires = [ "postgresqlBackup-hindsight.service" ];
      after = [ "postgresqlBackup-hindsight.service" ];
    };
    services.restic.backups.hermes.paths = [ backup.dumpDir ];
    systemd.services.restic-backups-hermes = {
      requires = [ "postgresqlBackup-hindsight.service" ];
      after = [ "postgresqlBackup-hindsight.service" ];
    };
  };
}
