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
# each folder both ways. An archive host only receives it, and keeps what a peer deletes or
# overwrites for the folder's keepDays
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
        myWiki = {
          id = "3heyc-wgheb";
          path = myWikiDir;
          phone = true;
          keepDays = 90;
        };

        # Claude Code shared state (chats, memory, plugins), no account cookies. Its transcripts
        # grow all day, and each version is a whole file, so the archive keeps them for less
        claude-shared = {
          id = "claude-shared";
          path = "${homeDir}/.local/share/claude-shared";
          phone = false;
          keepDays = 30;
        };
      };

  # Both units carry them, as restic-server.nix explains for its own
  mountGuard = {
    RequiresMountsFor = [ cfg.archive.dir ];
    ConditionPathIsMountPoint = cfg.archive.mountPoint;
  };
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
        assertions = [
          {
            assertion = lib.hasPrefix "${cfg.archive.mountPoint}/" cfg.archive.dir;
            message = "rokokol.syncthing.archive.dir must be on rokokol.syncthing.archive.mountPoint";
          }
        ];

        # The default user, not the owner: the archive needs no home. The owner reads the old
        # versions through the group, and the folders' files keep the modes of the peers
        services.syncthing = {
          # tailscale.nix trusts the tailnet interface, and the LAN stays shut out
          openDefaultPorts = false;

          # Nothing is set by hand here, so the configuration is the whole truth
          overrideDevices = true;
          overrideFolders = true;

          settings.folders = lib.mapAttrs (name: folder: {
            inherit (folder) id devices;
            path = "${cfg.archive.dir}/${name}";
            type = "receiveonly";
            versioning = {
              type = "staggered";
              params.maxAge = toString (folder.keepDays * 24 * 60 * 60);
            };
          }) folders;
        };

        users.users.${rokokolName}.extraGroups = [ config.services.syncthing.group ];

        systemd.services.syncthing = {
          unitConfig = mountGuard;
          # Not a tmpfiles rule, for the reason restic-server.nix gives
          serviceConfig.ExecStartPre = [
            "+${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o ${config.services.syncthing.user} -g ${config.services.syncthing.group} ${lib.escapeShellArg cfg.archive.dir}"
          ];
        };
        systemd.services.syncthing-init.unitConfig = mountGuard;
      })
    ]
  );
}
