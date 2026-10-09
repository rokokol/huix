{
  config,
  lib,
  pkgs,
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
      # A dump each night; the module removes the ones older than four weeks
      dump.enable = true;

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
    # of the web page. The wrapper runs `forgejo`, whose admin tools live under forgejo-cli
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
  };
}
