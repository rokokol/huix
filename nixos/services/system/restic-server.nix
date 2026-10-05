{
  config,
  lib,
  pkgs,
  ...
}:

# The receiving end of restic backups that nodes push over the tailnet. Each node has one
# htpasswd user, confined to its repository at /<user>/, append-only and never pruned. The
# repository key never reaches this host. The data lives on its own filesystem, and nothing
# runs or is created while that filesystem is not mounted
let
  cfg = config.rokokol.restic-server;
  unit = "restic-rest-server";
  # Both the socket and the service carry them. Without them on the service, a manual start
  # writes to the root filesystem. Without them on the socket, the port accepts a push and fails it
  mountGuard = {
    RequiresMountsFor = [ cfg.dataDir ];
    ConditionPathIsMountPoint = cfg.mountPoint;
  };
in
{
  options.rokokol.restic-server = {
    enable = lib.mkEnableOption "the append-only restic REST server";

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
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.dataDir == cfg.mountPoint || lib.hasPrefix "${cfg.mountPoint}/" cfg.dataDir;
        message = "rokokol.restic-server.dataDir must be on rokokol.restic-server.mountPoint";
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
      appendOnly = true;
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
      # Not a tmpfiles rule: tmpfiles runs at boot with or without the filesystem. This runs
      # only after the conditions above hold. Not on the service: its sandbox binds dataDir
      # for every command it starts, a "+" one too, and fails while dataDir is missing. The
      # service requires the socket, so the socket always starts first
      socketConfig.ExecStartPre = "${lib.getExe' pkgs.coreutils "install"} -d -m 0750 -o restic -g restic ${lib.escapeShellArg cfg.dataDir}";
    };

    systemd.services.${unit}.unitConfig = mountGuard;
  };
}
