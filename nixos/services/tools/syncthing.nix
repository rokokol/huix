{
  config,
  lib,
  pkgs,
  inputs,
  myWikiDir,
  rokokolName,
  ...
}:

# Syncthing between the hosts of this flake and the phone. Each host names its own device ID, and
# every other host takes it from there; a host with no ID yet is left out. A workstation shares
# each folder both ways. An archive host only receives it, unless a user there edits it, and
# keeps what a peer deletes or overwrites in snapshots, for the folder's `preserve`
let
  cfg = config.rokokol.syncthing;
  homeDir = "/home/${rokokolName}";
  port = 8384;

  # This host from its own configuration, so that whatever extends it, as a test does, is seen
  hosts = lib.mapAttrs (_: host: host.config) inputs.self.nixosConfigurations // {
    ${config.networking.hostName} = config;
  };
  peers = lib.filterAttrs (
    _: host: host.rokokol.syncthing.enable && host.rokokol.syncthing.deviceId != null
  ) hosts;

  # The tailnet name comes after discovery: the station's firewall is shut to the LAN, and a
  # peer at home finds it only through the tailnet
  peer = id: host: {
    inherit id;
    addresses = [
      "dynamic"
      "tcp://${host}:22000"
    ];
  };

  devices = lib.mapAttrs (name: host: peer host.rokokol.syncthing.deviceId name) peers // {
    # The phone never announces its tailnet address: the tailscale endpoint of its sing-box
    # makes no system interface, so Syncthing there cannot see it
    phone = peer "QAMHANE-X4B6XWI-45LGTZD-AH4BHDX-FHVWOWE-SBEHXO2-JL5TXBK-CBIUAQB" "mobile-1";
  };

  # Every host has every folder; `phone` adds the phone to it
  folders =
    lib.mapAttrs
      (_: folder: folder // { devices = lib.attrNames peers ++ lib.optional folder.phone "phone"; })
      {
        # `preserve` is how long the archive keeps the folder's snapshots, as btrbk's
        # snapshot_preserve: one a day for 30 days, then one a week for 13 weeks
        myWiki = {
          id = "3heyc-wgheb";
          path = myWikiDir;
          phone = true;
          preserve = "30d 13w";
        };

        # Claude Code shared state (chats, memory, plugins), no account cookies. Its transcripts
        # grow all day, so the archive keeps them for less
        claude-shared = {
          id = "claude-shared";
          path = "${homeDir}/.local/share/claude-shared";
          phone = false;
          preserve = "30d";
        };
      };

  # Every unit carries them, as restic-server.nix explains for its own
  mountGuard = {
    RequiresMountsFor = [ cfg.archive.dir ];
    ConditionPathIsMountPoint = cfg.archive.mountPoint;
  };

  # btrbk and the disk layout name a subvolume by its path inside the volume
  onVolume = lib.removePrefix "${cfg.archive.mountPoint}/";

  archived = lib.mapAttrs (name: _: "${cfg.archive.dir}/${name}") folders;

  inherit (config.services.syncthing) user group;

  # Makes a directory Syncthing's. One that another user left whole, as when the editor changes,
  # becomes Syncthing's whole, or Syncthing could not write a file in it
  own = pkgs.writeShellScript "syncthing-own" ''
    set -eu
    mode=$1
    dir=$2
    if [ -d "$dir" ] && [ "$(stat -c %U "$dir")" != ${user} ]; then
      chown -R ${user}:${group} "$dir"
    fi
    install -d -m "$mode" -o ${user} -g ${group} "$dir"
  '';
in
{
  options.rokokol.syncthing = {
    enable = lib.mkEnableOption "Syncthing between the workstations, the phone and the archive" // {
      default = config.rokokol.workstation.enable || cfg.archive.enable;
    };

    deviceId = lib.mkOption {
      type = lib.types.nullOr (lib.types.strMatching "[A-Z2-7]{7}(-[A-Z2-7]{7}){7}");
      default = null;
      example = "MNSJ7QK-4YOWUOS-3O5MSOT-UXON7VW-PZFY2YC-34MDG2H-UHTWJ7H-QLTDKQV";
      description = "This host's device ID, as its Syncthing shows it; the other hosts trust it";
    };

    archive = {
      enable = lib.mkEnableOption "a receive-only copy of every folder, with the old versions of its files";

      dir = lib.mkOption {
        type = lib.types.path;
        example = "/srv/backup/syncthing";
        description = "Directory of the folders, on the filesystem mounted at `mountPoint`";
      };

      mountPoint = lib.mkOption {
        type = lib.types.path;
        example = "/srv/backup";
        description = "Mountpoint of the archive's filesystem; Syncthing does not start without it";
      };

      snapshotDir = lib.mkOption {
        type = lib.types.path;
        example = "/srv/backup/snapshots/syncthing";
        description = "Directory of the read-only snapshots of every folder, on the same filesystem";
      };

      editor = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        example = "mya";
        description = ''
          A user who edits the folders on this host. Syncthing runs as that user, so the files
          are theirs, and sends their changes to the peers. With null, Syncthing runs as its
          own user and only receives
        '';
      };

      folders = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        readOnly = true;
        default = lib.mapAttrs' (name: folder: lib.nameValuePair folder.path archived.${name}) folders;
        defaultText = lib.literalMD "each folder's path on a workstation, to its directory under `dir`";
        description = "Where the workstations keep each folder, and where this host keeps it";
      };

      # A running host never makes them: a folder added later comes up as a plain directory,
      # and btrbk fails on it, which mails root
      subvolumes = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        readOnly = true;
        default = map onVolume (lib.attrValues archived ++ [ cfg.archive.snapshotDir ]);
        defaultText = lib.literalMD "each folder under `dir`, and `snapshotDir`";
        description = "Subvolumes of the archive, as paths inside `mountPoint`, for the disk layout to make";
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        services.syncthing = {
          enable = true;
          guiAddress = "127.0.0.1:${toString port}";
          settings.devices = devices;
        };

        environment.sessionVariables = {
          SYNCTHING_PORT = port;
        };
      }

      (lib.mkIf (!cfg.archive.enable) {
        services.syncthing = {
          user = rokokolName;
          dataDir = "${homeDir}/Documents";
          configDir = "${homeDir}/.config/syncthing";

          openDefaultPorts = true;

          # additive: myWiki also rides the phone, which is configured from the phone side
          overrideDevices = false;
          overrideFolders = false;

          settings.folders = lib.mapAttrs (_: folder: {
            inherit (folder) id path devices;
            type = "sendreceive";
          }) folders;
        };
      })

      (lib.mkIf cfg.archive.enable {
        assertions =
          map
            (option: {
              assertion = lib.hasPrefix "${cfg.archive.mountPoint}/" cfg.archive.${option};
              message = "rokokol.syncthing.archive.${option} must be on rokokol.syncthing.archive.mountPoint";
            })
            [
              "dir"
              "snapshotDir"
            ];

        # The editor or the default user, never the owner: whoever writes the folders must not
        # be root through sudo, or the snapshots would be in reach. The owner reads the folders
        # and the snapshots through the group. The files take the default modes, not the peers'
        # own: a private mode there, as on Claude Code's transcripts, would shut the owner out
        services.syncthing =
          lib.optionalAttrs (cfg.archive.editor != null) {
            user = cfg.archive.editor;
            group = cfg.archive.editor;
          }
          // {
            # tailscale.nix trusts the tailnet interface, and the LAN stays shut out
            openDefaultPorts = false;

            # Nothing is set by hand here, so the configuration is the whole truth
            overrideDevices = true;
            overrideFolders = true;

            settings.folders = lib.mapAttrs (name: folder: {
              inherit (folder) id devices;
              path = archived.${name};
              type = if cfg.archive.editor != null then "sendreceive" else "receiveonly";
              ignorePerms = true;
            }) folders;
          };

        # Snapshots and not Syncthing's versions: Syncthing keeps no version of a change made on
        # this host, and a snapshot keeps that change as well. A snapshot comes every 15 minutes
        # if its folder changed, and each one is kept for a day before `preserve` thins them out
        services.btrbk.instances.syncthing = {
          onCalendar = "*:0/15";
          settings = {
            timestamp_format = "long";
            snapshot_create = "onchange";
            snapshot_preserve_min = "1d";
            volume.${cfg.archive.mountPoint} = {
              snapshot_dir = onVolume cfg.archive.snapshotDir;
              subvolume = lib.mapAttrs' (
                name: folder: lib.nameValuePair (onVolume archived.${name}) { snapshot_preserve = folder.preserve; }
              ) folders;
            };
          };
        };

        users.users.${rokokolName}.extraGroups = [ group ];

        systemd.services.syncthing = {
          unitConfig = mountGuard;
          # The disk layout makes each folder as root's, and nixpkgs makes the data directory only
          # for its own user. Not a tmpfiles rule, for the reason restic-server.nix gives
          serviceConfig.ExecStartPre = [
            # Root's, as the disk layout makes it: one left to a user who is gone shuts out
            # everyone who reads the folders through it
            "+${lib.getExe' pkgs.coreutils "install"} -d -m 0755 -o root -g root ${lib.escapeShellArg cfg.archive.dir}"
          ]
          ++ lib.mapAttrsToList (dir: mode: "+${own} ${mode} ${lib.escapeShellArg dir}") (
            lib.genAttrs (lib.attrValues archived) (_: "0750")
            // {
              ${config.services.syncthing.dataDir} = "0700";
            }
          );
        };
        systemd.services.syncthing-init.unitConfig = mountGuard;
        systemd.services.btrbk-syncthing.unitConfig = mountGuard;
      })
    ]
  );
}
