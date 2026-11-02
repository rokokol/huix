{
  config,
  lib,
  pkgs,
  forgejoRunner,
  rokokolEmail,
  rokokolName,
  ...
}:

# A Forgejo forge for one owner, reached over HTTP through its tailnet-web site, which the LAN
# reaches too. Forgejo itself binds to loopback: its module listens on every address by default.
# There is no SSH server and no sign-up. The owner's admin account is made once, with a random
# first password that Forgejo asks to change on the first login
let
  cfg = config.rokokol.forgejo;
  forgejo = config.services.forgejo;
  port = 3000;
  backendPort = 3001;
  runnerId = import ../../../lib/forgejo-runner-id.nix lib;
  runnerSecret = name: "forgejo-runner-${name}";

  # The forgejo CLI with what it needs to find this instance, as the upstream dump unit sets it.
  # It runs as the forgejo user, which owns the state
  cli = pkgs.writeShellApplication {
    name = "forgejo-cli";
    text = ''
      export USER=${forgejo.user} HOME=${forgejo.stateDir}
      export FORGEJO_WORK_DIR=${forgejo.stateDir} FORGEJO_CUSTOM=${forgejo.customDir}
      exec ${lib.getExe forgejo.package} "$@"
    '';
    meta.description = "The forgejo command line, pointed at the instance of this host";
  };
in
{
  options.rokokol.forgejo = {
    enable = lib.mkEnableOption "the Forgejo forge";

    owner = lib.mkOption {
      type = lib.types.str;
      default = rokokolName;
      defaultText = lib.literalExpression "rokokolName";
      description = "Name of the admin account that is made on the first start";
    };

    initialPasswordFile = lib.mkOption {
      type = lib.types.path;
      default = "${forgejo.stateDir}/initial-admin-password";
      defaultText = lib.literalExpression ''"''${config.services.forgejo.stateDir}/initial-admin-password"'';
      readOnly = true;
      description = "File with the first password of the owner's account, readable by forgejo alone";
    };

    backup = {
      mountPoint = lib.mkOption {
        type = lib.types.path;
        example = "/srv/backup";
        description = "Mountpoint of the filesystem that holds the dump; the nightly dump does not run without it";
      };

      dumpDir = lib.mkOption {
        type = lib.types.path;
        example = "/srv/backup/forgejo-dump";
        description = ''
          Directory of the nightly dump, which the station's restic backup reads. The dump holds
          the whole forge in one archive, so it costs its size on every snapshot, and the four
          that the policy keeps cost that much again
        '';
      };
    };

    runners = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "nixos-pc" ];
      description = ''
        Names of the Actions runners to register. Each takes the last 24 hex characters of its
        secret from the sops secret forgejo-runner-<name>; lib/forgejo-runner-id.nix makes the rest
      '';
    };

    cli = lib.mkOption {
      type = lib.types.package;
      default = cli;
      defaultText = lib.literalMD "a `forgejo-cli` wrapper of `services.forgejo.package`";
      readOnly = true;
      description = "The forgejo command line for this instance, to run as the forgejo user";
    };
  };

  config = lib.mkIf cfg.enable {
    services.forgejo = {
      enable = true;
      # The dump is the backup of the forge: the station's restic backup reads this directory,
      # and the timer runs an hour before that backup, so the archive taken is of the same night
      dump = {
        enable = true;
        backupDir = cfg.backup.dumpDir;
        # Three days, not the module's four weeks: at a gigabyte a dump that would fill the
        # volume, and two days would still lose the archive after two failed nights
        age = "3d";
        interval = "02:45";
      };

      settings = {
        server = {
          HTTP_ADDR = "127.0.0.1";
          HTTP_PORT = backendPort;
          DOMAIN = config.networking.hostName;
          ROOT_URL = "http://${config.networking.hostName}:${toString port}/";
          DISABLE_SSH = true;
        };

        service.DISABLE_REGISTRATION = true;

        # Plain HTTP inside the tailnet, so a secure cookie would never come back
        session.COOKIE_SECURE = false;

        # Jobs wait for the PC, which may be off for days. The default cancels them after a day
        actions.ABANDONED_JOB_TIMEOUT = "168h";
      };
    };

    rokokol.tailnet-web.sites.forgejo = {
      inherit port;
      backend = "http://127.0.0.1:${toString backendPort}";
      # A push carries a whole pack, far over the nginx default of 1 MiB
      extraConfig = "client_max_body_size 512m;";
      lan = true;
    };

    environment.systemPackages = [ cli ];

    sops.secrets = lib.genAttrs (map runnerSecret cfg.runners) (_: { });
    sops.templates = lib.listToAttrs (
      map (
        name:
        lib.nameValuePair (runnerSecret name) {
          owner = forgejo.user;
          content = "${(runnerId name).prefix}${config.sops.placeholder.${runnerSecret name}}";
          restartUnits = [ "forgejo-runners.service" ];
        }
      ) cfg.runners
    );

    # Registration under a known secret is idempotent, so the runner needs no token copied out
    # of the web page. The wrapper runs `forgejo`, whose admin tools live under forgejo-cli. The
    # labels go with it because the command writes them even over an existing runner, while the
    # flag's empty default would store `[""]`, a label no job asks for
    systemd.services.forgejo-runners = lib.mkIf (cfg.runners != [ ]) {
      description = "Register the Forgejo Actions runners";
      requires = [ "forgejo.service" ];
      after = [ "forgejo.service" ];
      wantedBy = [ "multi-user.target" ];
      path = [ cli ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = forgejo.user;
        Group = forgejo.group;
      };
      script = lib.concatMapStrings (name: ''
        forgejo-cli forgejo-cli actions register --name ${name} \
          --labels ${lib.concatStringsSep "," forgejoRunner.labels} \
          --secret-file ${config.sops.templates.${runnerSecret name}.path}
      '') cfg.runners;
    };

    # The forgejo CLI prints the generated password, so it goes straight into the file and
    # never reaches the command line or the journal
    systemd.services.forgejo-owner = {
      description = "Create the owner's Forgejo account";
      requires = [ "forgejo.service" ];
      after = [ "forgejo.service" ];
      wantedBy = [ "multi-user.target" ];
      path = with pkgs; [
        cli
        gawk
        gnugrep
        gnused
      ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = forgejo.user;
        Group = forgejo.group;
        UMask = "0077";
      };
      # grep reads to the end, so that awk never dies of a closed pipe
      script = ''
        set -o pipefail
        if forgejo-cli admin user list --admin | awk 'NR > 1 { print $2 }' | grep -x ${cfg.owner} >/dev/null; then
          exit 0
        fi
        forgejo-cli admin user create --admin --username ${cfg.owner} \
          --email ${rokokolEmail} \
          --random-password --must-change-password \
          | sed -n "s/^generated random password is '\(.*\)'$/\1/p" >${cfg.initialPasswordFile}
        chmod 0400 ${cfg.initialPasswordFile}
        test -s ${cfg.initialPasswordFile}
      '';
    };

    # The dump lands on the backup volume, and a missing mount would leave it on the root
    # filesystem and hide it from the backup. The directory is made here rather than by a
    # tmpfiles rule, which runs before the volume is mounted
    systemd.services.forgejo-dump.unitConfig = {
      RequiresMountsFor = [ cfg.backup.dumpDir ];
      ConditionPathIsMountPoint = cfg.backup.mountPoint;
    };
    systemd.services.forgejo-dump.serviceConfig.ExecStartPre = [
      "+${pkgs.coreutils}/bin/install -d -m 0750 -o ${forgejo.user} -g ${forgejo.group} ${cfg.backup.dumpDir}"
    ];

    services.restic.backups.station.paths = [ cfg.backup.dumpDir ];
    systemd.services.restic-backups-station.requires = [ "forgejo-dump.service" ];
    systemd.services.restic-backups-station.after = [ "forgejo-dump.service" ];
  };
}
