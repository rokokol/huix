{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:

# A CalDAV server for the owner's calendars, reached through its tailnet-web site. Radicale binds
# to loopback, and every request needs a login from the htpasswd file. The calendars are plain
# files on the backup filesystem, with snapshots every 15 minutes, so an event that a client
# deleted can be restored. A calendar belongs to `owner`, and each user in `sharedWith` finds it
# in their own home through a symlink: a CalDAV client lists only the calendars of its own home
let
  cfg = config.rokokol.radicale;
  port = 5232;
  backendPort = 5233;
  root = "${cfg.dataDir}/collection-root";
  # btrbk and the disk layout name a subvolume by its path inside the volume
  onVolume = lib.removePrefix "${cfg.mountPoint}/";
  mountGuard = {
    RequiresMountsFor = [ cfg.dataDir ];
    ConditionPathIsMountPoint = cfg.mountPoint;
  };

  # Radicale reads the type and the name of a collection from this file
  props =
    name: collection:
    pkgs.writeText "radicale-${name}.props" (
      builtins.toJSON {
        tag = "VCALENDAR";
        "C:supported-calendar-component-set" = lib.concatStringsSep "," collection.components;
        "D:displayname" = collection.displayName;
      }
    );

  setup = pkgs.writeShellScript "radicale-data" ''
    set -eu
    PATH=${
      lib.makeBinPath (
        with pkgs;
        [
          btrfs-progs
          coreutils
        ]
      )
    }
    for dir in ${lib.escapeShellArg cfg.dataDir} ${lib.escapeShellArg cfg.snapshotDir}; do
      [ -e "$dir" ] || { mkdir -p "''${dir%/*}" && btrfs subvolume create "$dir"; }
    done
    for dir in ${cfg.dataDir} ${root} ${root}/${cfg.owner}; do
      install -d -m 0750 -o radicale -g radicale "$dir"
    done
    ${lib.concatStrings (
      lib.mapAttrsToList (name: collection: ''
        install -d -m 0750 -o radicale -g radicale ${root}/${cfg.owner}/${name}
        # Only when missing: a client may rename the calendar, and that name is its own
        [ -e ${root}/${cfg.owner}/${name}/.Radicale.props ] ||
          install -m 0640 -o radicale -g radicale ${props name collection} \
            ${root}/${cfg.owner}/${name}/.Radicale.props
        ${lib.concatMapStrings (user: ''
          install -d -m 0750 -o radicale -g radicale ${root}/${user}
          link=${root}/${user}/${name}
          if [ -e "$link" ] && [ ! -L "$link" ]; then
            echo "$link is a collection of its own, so ${user} would not see ${cfg.owner}'s" >&2
            exit 1
          fi
          ln -sfn ../${cfg.owner}/${name} "$link"
          chown -h radicale:radicale "$link"
        '') cfg.sharedWith}
      '') cfg.collections
    )}
  '';
in
{
  options.rokokol.radicale = {
    enable = lib.mkEnableOption "the Radicale CalDAV server, with snapshots of its calendars";

    dataDir = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup/radicale";
      description = "Directory of the calendars, on the filesystem mounted at `mountPoint`";
    };

    mountPoint = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup";
      description = "Mountpoint of the filesystem with `dataDir`; the server does not start without it";
    };

    snapshotDir = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup/snapshots/radicale";
      description = "Directory of the read-only snapshots of `dataDir`, on the same filesystem";
    };

    preserve = lib.mkOption {
      type = lib.types.str;
      default = "14d";
      description = ''
        How long the snapshots of `dataDir` are kept, as btrbk's snapshot_preserve. It is how
        long an event that a client deleted can still be restored
      '';
    };

    owner = lib.mkOption {
      type = lib.types.str;
      default = rokokolName;
      description = "Login whose home holds the calendars";
    };

    sharedWith = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "mya" ];
      description = "Logins that read and write every calendar of `owner`, each from their own home";
    };

    collections = lib.mkOption {
      default = { };
      description = "Calendars of `owner`, by the last segment of their URL";
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            components = lib.mkOption {
              type = lib.types.nonEmptyListOf (
                lib.types.enum [
                  "VEVENT"
                  "VTODO"
                  "VJOURNAL"
                ]
              );
              example = [ "VTODO" ];
              description = "Kinds of item that the calendar holds";
            };

            displayName = lib.mkOption {
              type = lib.types.str;
              description = "Name that clients show for the calendar until one renames it";
            };
          };
        }
      );
    };

    url = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "http://${config.networking.hostName}:${toString port}/";
      defaultText = lib.literalExpression ''"http://''${config.networking.hostName}:5232/"'';
      description = "Root URL of the server inside the tailnet, which a CalDAV client starts from";
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
        message = "rokokol.radicale.dataDir and snapshotDir must be under rokokol.radicale.mountPoint";
      }
      {
        assertion = !lib.elem cfg.owner cfg.sharedWith;
        message = "rokokol.radicale.sharedWith cannot hold the owner, ${cfg.owner}";
      }
    ];

    sops.secrets."radicale-htpasswd" = {
      owner = "radicale";
      group = "radicale";
      mode = "0440";
      restartUnits = [ "radicale.service" ];
    };

    services.radicale = {
      enable = true;
      settings = {
        server.hosts = [ "127.0.0.1:${toString backendPort}" ];
        auth = {
          type = "htpasswd";
          htpasswd_filename = config.sops.secrets."radicale-htpasswd".path;
          htpasswd_encryption = "bcrypt";
        };
        storage.filesystem_folder = cfg.dataDir;
      };
      # Each login reads the root and writes in its own home. A shared calendar is a symlink in
      # that home, so no rule names another login's calendars
      rights = {
        root = {
          user = ".+";
          collection = "";
          permissions = "R";
        };
        principal = {
          user = ".+";
          collection = "{user}";
          permissions = "RW";
        };
        calendars = {
          user = ".+";
          collection = "{user}/[^/]+";
          permissions = "rw";
        };
      };
    };

    rokokol.tailnet-web.sites.radicale = {
      inherit port;
      backend = "http://127.0.0.1:${toString backendPort}";
    };

    # Not a tmpfiles rule and not in the service, for the reasons restic-server.nix gives. A
    # subvolume, so btrbk can take snapshots of it
    systemd.services.radicale-data = {
      description = "Calendars of Radicale on the backup filesystem";
      requiredBy = [ "radicale.service" ];
      before = [ "radicale.service" ];
      unitConfig = mountGuard;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        ExecStart = setup;
      };
    };

    systemd.services.radicale.unitConfig = mountGuard;

    # Every 15 minutes when a calendar changed, and each one is kept for a day before `preserve`
    # thins them out. Syncthing's archive in syncthing.nix does the same
    services.btrbk.instances.radicale = {
      onCalendar = "*:0/15";
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

    # The snapshot directory is made by radicale-data
    systemd.services.btrbk-radicale.wants = [ "radicale-data.service" ];
    systemd.services.btrbk-radicale.after = [ "radicale-data.service" ];
    systemd.services.btrbk-radicale.unitConfig = {
      RequiresMountsFor = [
        cfg.dataDir
        cfg.snapshotDir
      ];
      ConditionPathIsMountPoint = cfg.mountPoint;
    };
  };
}
