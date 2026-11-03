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
  # A writable snapshot beside the subvolume, outside the snapshot directory btrbk owns
  snapshot = "${cfg.mountPoint}/hermes-snapshot";
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
    subvolumes = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      readOnly = true;
      default = lib.optionals cfg.enable (map onVolume [ cfg.dataDir ]);
      defaultText = lib.literalMD "The state subvolume when the backup is enabled";
      description = "Subvolumes for the disk layout to create";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = lib.hasPrefix "${cfg.mountPoint}/" cfg.dataDir;
        message = "Hermes state must be under the backup mountpoint";
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

    # The archive is built here rather than in restic's prepare hook: the hook holds one command,
    # and the station's single backup serves four sources. See WORKAROUNDS.md for the 1980 step
    systemd.services.hermes-backup-zip = {
      description = "Portable archive of the Hermes state";
      unitConfig = guard;
      serviceConfig.Type = "oneshot";
      # The walk reads a snapshot: the agent prunes its own cron output and the handoffs of finished
      # workers as it works, so a file the walk listed could vanish before the archive reached it
      script = ''
        set -eu
        ${pkgs.btrfs-progs}/bin/btrfs subvolume delete "${snapshot}" 2>/dev/null || true
        ${pkgs.btrfs-progs}/bin/btrfs subvolume snapshot ${cfg.dataDir} "${snapshot}"
        trap '${pkgs.btrfs-progs}/bin/btrfs subvolume delete "${snapshot}"' EXIT
        ${pkgs.findutils}/bin/find "${snapshot}" ! -newermt 1980-01-02 \
          -exec ${pkgs.coreutils}/bin/touch -h -d 1980-01-02 {} +
        ${pkgs.util-linux}/bin/runuser -u ${agent.user} -- \
          ${pkgs.coreutils}/bin/env HOME=${agent.home} HERMES_HOME="${snapshot}" \
          ${lib.getExe package} backup --output ${cache}/current.zip --keep 0
        test -s ${cache}/current.zip
      '';
    };

    services.restic.backups.station.paths = [ "${cache}/current.zip" ];
    # Wanted, not required: a broken archive must not cost the snapshot of the other three
    # sources, and its own failure reaches the owner through OnFailure
    systemd.services.restic-backups-station.wants = [ "hermes-backup-zip.service" ];
    systemd.services.restic-backups-station.after = [ "hermes-backup-zip.service" ];
  };
}
