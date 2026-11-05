{
  config,
  lib,
  pkgs,
  inputs,
  rokokolName,
  ...
}:

let
  cfg = config.rokokol.drive-backup;
  restic = config.rokokol.restic-server;
  package = pkgs.callPackage ../../../lib/drive-backup-package.nix { inherit inputs; };
  stateDir = "/var/lib/restic-cloud";
  successFile = "${stateDir}/success.json";
  snapshotLock = "/run/lock/restic-cloud-snapshots.lock";
in
{
  options.rokokol.drive-backup = {
    enable = lib.mkEnableOption "Google Drive backup credentials" // {
      default = config.rokokol.workstation.enable;
    };
    cloud = {
      enable = lib.mkEnableOption "a daily cloud mirror of every restic repository";
      destination = lib.mkOption {
        type = lib.types.str;
        default = "drive-backup:backups/restic";
        description = "Dedicated rclone path for the encrypted restic mirror";
      };
      configFile = lib.mkOption {
        type = lib.types.path;
        default = "${stateDir}/rclone.conf";
        description = "Private writable rclone configuration after explicit OAuth authorization";
      };
      onCalendar = lib.mkOption {
        type = lib.types.str;
        default = "*-*-* 04:30:00";
        description = "Cloud mirror schedule in systemd calendar syntax";
      };
      maxAge = lib.mkOption {
        type = lib.types.ints.positive;
        default = 36 * 3600;
        description = "Maximum age of a successful cloud mirror, in seconds";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        environment.systemPackages = lib.optional cfg.cloud.enable package;

        sops.secrets.drive-backup-client = {
          sopsFile = builtins.path {
            name = "drive-backup-client.json";
            path = "${inputs.self}/secrets/drive-backup.json";
          };
          format = "json";
          key = "";
          owner = rokokolName;
          mode = "0400";
        };
      }
      (lib.mkIf cfg.cloud.enable {
        assertions = [
          {
            assertion = restic.enable;
            message = "rokokol.drive-backup.cloud needs the station's restic server";
          }
          {
            assertion =
              let
                path = lib.last (lib.splitString ":" cfg.cloud.destination);
                parts = lib.splitString "/" (lib.removePrefix "/" (lib.removeSuffix "/" path));
              in
              builtins.match "[A-Za-z0-9_-]+:[^:]+" cfg.cloud.destination != null
              && lib.all (part: part != "" && part != "." && part != "..") parts;
            message = "The cloud mirror needs a dedicated non-root rclone path";
          }
        ];

        # Keep btrbk retention from removing the snapshot during an upload
        systemd.tmpfiles.rules = [ "f ${snapshotLock} 0660 btrbk btrbk -" ];
        systemd.services.btrbk-restic.serviceConfig.ExecStart = lib.mkForce (
          "${lib.getExe' pkgs.util-linux "flock"} ${snapshotLock} "
          + "${lib.getExe pkgs.btrbk} -c /etc/btrbk/restic.conf run"
        );

        systemd.services.restic-cloud = {
          description = "Mirror every encrypted restic repository to Google Drive";
          wants = [ "network-online.target" ];
          after = [
            "network-online.target"
            "restic-backups-station.service"
          ];
          unitConfig = {
            RequiresMountsFor = [ restic.snapshotDir ];
            ConditionPathIsMountPoint = restic.mountPoint;
            StartLimitIntervalSec = "6h";
            StartLimitBurst = 3;
          };
          # A retry must request a fresh snapshot, not reuse one that captured a restic lock
          preStart = "${lib.getExe' pkgs.systemd "systemctl"} start btrbk-restic.service";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.escapeShellArgs [
              "${package}/bin/restic-cloud"
              "mirror"
              "--snapshot-dir"
              restic.snapshotDir
              "--accounts"
              config.services.restic.server.htpasswd-file
              "--destination"
              cfg.cloud.destination
              "--config"
              cfg.cloud.configFile
              "--lock"
              snapshotLock
              "--state"
              successFile
            ];
            StateDirectory = "restic-cloud";
            StateDirectoryMode = "0700";
            UMask = "0077";
            Restart = "on-failure";
            RestartSec = "30min";
            TimeoutStartSec = "20h";
            NoNewPrivileges = true;
            PrivateTmp = true;
            ProtectHome = true;
            ProtectSystem = "strict";
            ReadWritePaths = [
              stateDir
              snapshotLock
            ];
          };
        };
        systemd.timers.restic-cloud = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = cfg.cloud.onCalendar;
            Persistent = true;
            RandomizedDelaySec = "10min";
          };
        };

        systemd.services.restic-cloud-heartbeat = {
          description = "Check the age of the last successful restic cloud mirror";
          serviceConfig = {
            Type = "oneshot";
            ExecStart = lib.escapeShellArgs [
              "${package}/bin/restic-cloud"
              "check"
              "--state"
              successFile
              "--max-age"
              (toString cfg.cloud.maxAge)
              "--config"
              cfg.cloud.configFile
              "--destination"
              cfg.cloud.destination
            ];
            NoNewPrivileges = true;
            PrivateNetwork = true;
            ProtectHome = true;
            ProtectSystem = "strict";
          };
        };
        systemd.timers.restic-cloud-heartbeat = {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnCalendar = "hourly";
            Persistent = true;
          };
        };
      })
    ]
  );
}
