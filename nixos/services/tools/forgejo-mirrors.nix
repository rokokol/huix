{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Forgejo pull mirrors of the GitHub repositories that the token in the secret
# github-mirror-token sees as its user's own. A daily run makes the mirrors that are missing
# and keeps them when the token changes; Forgejo itself fetches each mirror on its own interval.
# The run talks to Forgejo with an API token of the owner, which the forgejo CLI makes on the
# first run; deleting its file makes a new one. Deleting or renaming a repository of a user
# takes the user scope as well as the repository one
let
  cfg = config.rokokol.forgejo-mirrors;
  forgejo = config.services.forgejo;
  inherit (forgejo.settings) server;
  stateDirectory = "forgejo-mirrors";
  state = "/var/lib/${stateDirectory}";
  script = builtins.path {
    name = "forgejo-mirrors";
    path = "${inputs.self}/scripts/forgejo-mirrors.sh";
  };
in
{
  options.rokokol.forgejo-mirrors = {
    enable = lib.mkEnableOption "Forgejo mirrors of the owner's GitHub repositories";

    githubApi = lib.mkOption {
      type = lib.types.str;
      default = "https://api.github.com";
      description = "Base URL of the GitHub API";
    };

    forks = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "some-fork" ];
      description = "Forks that get a mirror too; every repository that is not a fork gets one anyway";
    };

    exclude = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      example = [ "huge-archive" ];
      description = "Repositories that get no mirror; a mirror made before stays";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.rokokol.forgejo.enable;
        message = "rokokol.forgejo-mirrors mirrors into the Forgejo of rokokol.forgejo";
      }
    ];

    sops.secrets."github-mirror-token".owner = forgejo.user;

    systemd.services.forgejo-mirrors = {
      description = "Mirror the owner's GitHub repositories into Forgejo";
      requires = [ "forgejo.service" ];
      wants = [ "network-online.target" ];
      after = [
        "forgejo-owner.service"
        "network-online.target"
      ];
      path = with pkgs; [
        config.rokokol.forgejo.cli
        coreutils
        curl
        jq
      ];
      preStart = ''
        if [ ! -s ${state}/api-token ]; then
          forgejo-cli admin user generate-access-token --raw \
            --username ${config.rokokol.forgejo.owner} --token-name "mirrors-$(date +%s)" \
            --scopes write:repository,write:user >${state}/api-token
        fi
      '';
      serviceConfig = {
        Type = "oneshot";
        User = forgejo.user;
        Group = forgejo.group;
        StateDirectory = stateDirectory;
        StateDirectoryMode = "0700";
        UMask = "0077";
        ExecStart = lib.escapeShellArgs (
          [
            (lib.getExe pkgs.bash)
            script
            "sync"
          ]
          ++ lib.concatMap (name: [
            "-x"
            name
          ]) cfg.exclude
          ++ [
            cfg.githubApi
            config.sops.secrets."github-mirror-token".path
            "http://${server.HTTP_ADDR}:${toString server.HTTP_PORT}"
            "${state}/api-token"
            config.rokokol.forgejo.owner
            state
          ]
          ++ cfg.forks
        );
      };
    };

    systemd.timers.forgejo-mirrors = {
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "15min";
        OnCalendar = "daily";
        # A day missed while the host was off runs at the next boot
        Persistent = true;
      };
    };
  };
}
