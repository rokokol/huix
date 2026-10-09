{
  config,
  lib,
  inputs,
  utils,
  ...
}:

# A Forgejo Actions runner that takes jobs from the station and runs each in a Docker container.
# The runner trusts no workflow: it has only docker:// labels, so no job runs on this host, and
# its container settings hold whatever a workflow asks for. A job gets no Docker socket, no
# privileged mode and no volume of this host; the runner drops --privileged, --cap-add, --device
# and the host network from a job's container options on its own. Jobs run one at a time and
# give way to the desktop when the CPU is busy. The runner itself can reach the root Docker
# daemon, so a flaw in the runner, not in a job, is what this setup trusts
let
  cfg = config.rokokol.forgejo-runner;
  id = import ../../../lib/forgejo-runner-id.nix lib cfg.name;
  secret = "forgejo-runner-${cfg.name}";
in
{
  options.rokokol.forgejo-runner = {
    enable = lib.mkEnableOption "a Forgejo Actions runner with Docker";

    name = lib.mkOption {
      type = lib.types.str;
      default = config.networking.hostName;
      defaultText = lib.literalExpression "config.networking.hostName";
      description = "Name the forge registers the runner under, in its `rokokol.forgejo.runners`";
    };

    url = lib.mkOption {
      type = lib.types.str;
      example = "http://forge:3000/";
      description = "Root URL of the Forgejo that hands out the jobs";
    };

    labels = lib.mkOption {
      type = lib.types.listOf (lib.types.strMatching "[^:]+:docker://.+");
      default = [
        "docker:docker://data.forgejo.org/oci/node:22-bookworm"
        "ubuntu-latest:docker://data.forgejo.org/oci/node:22-bookworm"
      ];
      description = "Labels the runner takes jobs for, each mapped to the image the job runs in";
    };

    unit = lib.mkOption {
      type = lib.types.str;
      default = "forgejo-runner-${utils.escapeSystemdPath cfg.name}.service";
      defaultText = lib.literalExpression ''"forgejo-runner-''${utils.escapeSystemdPath name}.service"'';
      readOnly = true;
      description = "The runner's systemd unit, whose name the nixpkgs module escapes as a path";
    };

    secretsFile = lib.mkOption {
      type = lib.types.path;
      default = builtins.path {
        name = "station-secrets";
        path = "${inputs.self}/secrets/station.yaml";
      };
      defaultText = lib.literalExpression ''"''${inputs.self}/secrets/station.yaml"'';
      description = ''
        sops file with the secret forgejo-runner-<name>, the same file the forge reads it from,
        so the secret is written once
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.virtualisation.docker.enable;
        message = "rokokol.forgejo-runner runs its jobs in Docker, which is not enabled";
      }
    ];

    sops.secrets.${secret}.sopsFile = cfg.secretsFile;
    sops.templates.${secret} = {
      content = "${id.prefix}${config.sops.placeholder.${secret}}";
      restartUnits = [ cfg.unit ];
    };

    services.forgejo-runner.instances.${cfg.name} = {
      enable = true;
      settings = {
        runner = {
          capacity = 1;
          inherit (cfg) labels;
        };
        container = {
          privileged = false;
          # A volume a workflow names is dropped; only the runner's own work volumes stay
          valid_volumes = [ ];
          # No Docker socket in a job container
          docker_host = "-";
          # A quarter of the default CPU weight, so a build yields to the desktop
          options = "--cpu-shares=256";
        };
        server.connections.${cfg.name} = {
          inherit (cfg) url;
          inherit (id) uuid;
        };
      };
      secrets.server.connections.${cfg.name}.token_url = config.sops.templates.${secret}.path;
    };
  };
}
