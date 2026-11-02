{
  config,
  lib,
  pkgs,
  ...
}:

# Hermes makes consistent SQLite copies, and the station's own restic backup takes the archive
let
  agent = config.rokokol.mya-agent;
  cfg = agent.hermes.backup;
  onVolume = lib.removePrefix "${cfg.mountPoint}/";
  cache = "/var/cache/hermes-backup";
  package = config.services.hermes-agent.package;
  guard = {
    RequiresMountsFor = [ cfg.dataDir ];
    ConditionPathIsMountPoint = cfg.mountPoint;
  };
in
{
  options.rokokol.mya-agent.hermes.backup = {
    enable = lib.mkEnableOption "Hermes state snapshots and a local restic backup" // {
      default = agent.enable;
      defaultText = lib.literalExpression "config.rokokol.mya-agent.enable";
    };
    mountPoint = lib.mkOption {
      type = lib.types.str;
      description = "Mountpoint of the backup volume";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "Subvolume that holds the mutable Hermes home";
    };
    snapshotDir = lib.mkOption {
      type = lib.types.str;
      description = "Directory of Hermes state snapshots on the backup volume";
    };
    subvolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = lib.optionals cfg.enable (
        map onVolume [
          cfg.dataDir
          cfg.snapshotDir
        ]
      );
      defaultText = lib.literalMD "The state and snapshot subvolumes when the backup is enabled";
      description = "Subvolumes for the disk layout to create";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.all (path: lib.hasPrefix "${cfg.mountPoint}/" path) [
          cfg.dataDir
          cfg.snapshotDir
        ];
        message = "Hermes state and snapshots must be under the backup mountpoint";
      }
    ];
    fileSystems."${agent.home}/.hermes" = {
      device = cfg.dataDir;
      fsType = "none";
      options = [
        "bind"
        "nofail"
        "x-systemd.requires-mounts-for=${cfg.mountPoint}"
      ];
      depends = [ cfg.mountPoint ];
    };
    systemd.services.hermes-agent.unitConfig = guard // {
      ConditionPathIsMountPoint = "${agent.home}/.hermes";
    };
    systemd.services.hermes-backend.unitConfig = guard // {
      ConditionPathIsMountPoint = "${agent.home}/.hermes";
    };
    # Activation can precede the backup mount on boot; reuse its setup after the bind mount
    systemd.services.hermes-state = {
      requiredBy = [
        "hermes-agent.service"
        "hermes-backend.service"
      ];
      before = [
        "hermes-agent.service"
        "hermes-backend.service"
      ];
      after = [ "home-manager-${agent.user}.service" ];
      unitConfig = {
        RequiresMountsFor = [ "${agent.home}/.hermes" ];
        ConditionPathIsMountPoint = "${agent.home}/.hermes";
      };
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = config.system.activationScripts.hermes-agent-setup.text + ''
        chown -R ${agent.user}:${agent.user} ${agent.home}/.hermes
        chmod 0710 ${agent.home}
      '';
    };
    systemd.tmpfiles.rules = [ "d ${cache} 0700 ${agent.user} ${agent.user} -" ];

    services.btrbk.instances.hermes = {
      onCalendar = "daily";
      settings = {
        timestamp_format = "long";
        snapshot_create = "onchange";
        snapshot_preserve_min = "1d";
        volume.${cfg.mountPoint} = {
          snapshot_dir = onVolume cfg.snapshotDir;
          subvolume.${onVolume cfg.dataDir}.snapshot_preserve = "14d";
        };
      };
    };
    systemd.services.btrbk-hermes.unitConfig = guard;

    # The archive is built here rather than in restic's prepare hook: the hook holds one command,
    # and the station's single backup serves four sources. See WORKAROUNDS.md for the 1980 step
    systemd.services.hermes-backup-zip = {
      description = "Portable archive of the Hermes state";
      unitConfig = guard;
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.findutils}/bin/find ${agent.home}/.hermes ! -newermt 1980-01-02 \
          -exec ${pkgs.coreutils}/bin/touch -h -d 1980-01-02 {} +
        ${pkgs.util-linux}/bin/runuser -u ${agent.user} -- \
          ${pkgs.coreutils}/bin/env HOME=${agent.home} HERMES_HOME=${agent.home}/.hermes \
          ${lib.getExe package} backup --output ${cache}/current.zip --keep 0
        test -s ${cache}/current.zip
      '';
    };

    services.restic.backups.station.paths = [ "${cache}/current.zip" ];
    systemd.services.restic-backups-station.requires = [ "hermes-backup-zip.service" ];
    systemd.services.restic-backups-station.after = [ "hermes-backup-zip.service" ];
  };
}
