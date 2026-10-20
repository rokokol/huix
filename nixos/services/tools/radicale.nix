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
# deleted can be restored. The calendars themselves are data: a client makes them, and nothing
# here names one. Each login in `sharedWith` has the owner's home as its own, through a symlink,
# because a CalDAV client lists only the calendars of its own home
let
  cfg = config.rokokol.radicale;
  radicale = config.services.radicale;
  port = 5232;
  backendPort = 5233;
  root = "${cfg.dataDir}/collection-root";
  logins = [ cfg.owner ] ++ cfg.sharedWith;
  # nixos/services/tools/dav-mcp.nix gives the same secret to the login's own client
  passwordOf = login: "radicale-password-${login}";
  # btrbk and the disk layout name a subvolume by its path inside the volume
  onVolume = lib.removePrefix "${cfg.mountPoint}/";
  mountGuard = {
    RequiresMountsFor = [ cfg.dataDir ];
    ConditionPathIsMountPoint = cfg.mountPoint;
  };

  # The disk layout makes dataDir as root's and has no option for an owner. A missing dataDir
  # fails here instead of turning into a plain directory that btrbk cannot snapshot
  prepare = pkgs.writeShellScript "radicale-prepare" ''
    set -eu
    PATH=${pkgs.coreutils}/bin
    chown ${radicale.user}:${radicale.group} ${cfg.dataDir}
    chmod 0750 ${cfg.dataDir}
    install -d -m 0750 -o ${radicale.user} -g ${radicale.group} ${root}
    ${lib.concatMapStrings (login: ''
      if [ -e ${root}/${login} ] && [ ! -L ${root}/${login} ]; then
        echo "${root}/${login} is a home of its own, so ${login} would not see ${cfg.owner}'s calendars" >&2
        exit 1
      fi
      ln -sfn ${cfg.owner} ${root}/${login}
      chown -h ${radicale.user}:${radicale.group} ${root}/${login}
    '') cfg.sharedWith}
  '';
in
{
  options.rokokol.radicale = {
    enable = lib.mkEnableOption "the Radicale CalDAV server, with snapshots of its calendars";

    dataDir = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup/radicale";
      description = "Subvolume of the calendars, on the filesystem mounted at `mountPoint`";
    };

    mountPoint = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup";
      description = "Mountpoint of the filesystem with `dataDir`; the server does not start without it";
    };

    snapshotDir = lib.mkOption {
      type = lib.types.path;
      example = "/srv/backup/snapshots/radicale";
      description = "Subvolume of the read-only snapshots of `dataDir`, on the same filesystem";
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
      description = "Logins that read, write and make calendars in the home of `owner`";
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

    # One password per login, which its client reads too, so the file holds it in the clear. A
    # hash would guard only this file, and the passwords lie decrypted beside it in any case
    sops.secrets = lib.genAttrs (map passwordOf logins) (_: { });
    sops.templates."radicale-htpasswd" = {
      owner = radicale.user;
      inherit (radicale) group;
      mode = "0440";
      restartUnits = [ "radicale.service" ];
      content = lib.concatMapStrings (
        login: "${login}:${config.sops.placeholder.${passwordOf login}}\n"
      ) logins;
    };

    services.radicale = {
      enable = true;
      settings = {
        server.hosts = [ "127.0.0.1:${toString backendPort}" ];
        auth = {
          type = "htpasswd";
          htpasswd_filename = config.sops.templates."radicale-htpasswd".path;
          htpasswd_encryption = "plain";
        };
        storage.filesystem_folder = cfg.dataDir;
      };
      # Each login reads the root and works in its own home. A shared home is a symlink, so no
      # rule names another login's calendars
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

    systemd.services.radicale = {
      unitConfig = mountGuard;
      # "+": root's, outside the sandbox, which runs the server as its own user
      serviceConfig.ExecStartPre = [ "+${prepare}" ];
    };

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

    systemd.services.btrbk-radicale.unitConfig = {
      RequiresMountsFor = [
        cfg.dataDir
        cfg.snapshotDir
      ];
      ConditionPathIsMountPoint = cfg.mountPoint;
    };
  };
}
