{
  config,
  lib,
  pkgs,
  rokokolName,
  ...
}:
let
  cfg = config.rokokol.hindsight;
  models = import ../../../../lib/ai-models.nix;
  hosts = models.chat.${models.memory.model};
  secret = name: config.sops.placeholder.${name};
  secretsFile = ../../../../secrets/hindsight.yaml;
  pgDir = config.services.postgresql.dataDir;
  bankTemplate = pkgs.writeText "hindsight-bank-template.json" (
    builtins.toJSON {
      version = "1";
      mental_models = [
        {
          id = "owner-working-brief";
          name = "Owner working brief";
          source_query = "Synthesize a concise working brief for the owner: active projects, systems and services, durable preferences, important decisions, exact paths and commands, and open work. Prefer durable facts over recent chatter.";
          tags = [ ];
          max_tokens = 4096;
          trigger = {
            mode = "delta";
            refresh_cron = "0 0 * * *";
            full_refresh_cron = "0 0 * * 0";
          };
        }
      ];
    }
  );
in
{
  options.rokokol.hindsight = {
    enable = lib.mkEnableOption "shared Hindsight memory";
    client.enable = lib.mkEnableOption "access to shared Hindsight memory" // {
      default = config.rokokol.workstation.enable || cfg.enable;
    };
    port = lib.mkOption {
      type = lib.types.port;
      default = 8888;
      description = "Loopback API port";
    };
    publicPort = lib.mkOption {
      type = lib.types.port;
      default = 8788;
      description = "Authenticated API port on the tailnet";
    };
    # The dashboard draws the ceiling as a threshold, so the number lives here and nowhere else
    poolMin = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
      description = "Connections the database pool keeps open";
    };
    poolMax = lib.mkOption {
      type = lib.types.ints.positive;
      default = 5;
      description = "Ceiling on the connections of the database pool";
    };
    bank = lib.mkOption {
      type = lib.types.str;
      default = "shared";
      description = "Memory bank shared by pi and Hermes";
    };
    dataDir = lib.mkOption {
      type = lib.types.str;
      description = "PostgreSQL subvolume on the backup volume";
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.client.enable {
      sops.secrets.hindsight-client-token = {
        sopsFile = secretsFile;
        key = "api-token";
        owner = rokokolName;
      };
    })
    (lib.mkIf cfg.enable {
      users.groups.hindsight = { };
      users.users.hindsight = {
        isSystemUser = true;
        group = "hindsight";
      };
      sops.secrets.openrouter-api-key = { };
      sops.secrets.hindsight-api-token = {
        sopsFile = secretsFile;
        key = "api-token";
      };
      sops.templates."hindsight.env" = {
        owner = "hindsight";
        content = ''
          HINDSIGHT_API_LLM_API_KEY=${secret "openrouter-api-key"}
          HINDSIGHT_API_EMBEDDINGS_OPENAI_API_KEY=${secret "openrouter-api-key"}
          HINDSIGHT_API_TENANT_API_KEY=${secret "hindsight-api-token"}
          HINDSIGHT_API_MCP_AUTH_TOKEN=${secret "hindsight-api-token"}
          HINDSIGHT_API_RERANKER_OPENROUTER_API_KEY=${secret "openrouter-api-key"}
        '';
      };
      services.postgresql = {
        enable = true;
        package = pkgs.postgresql_18;
        extensions = ps: [ ps.pgvector ];
        enableTCPIP = false;
        initdbArgs = [
          "--encoding=UTF8"
          "--locale=C"
        ];
        ensureDatabases = [ "hindsight" ];
        ensureUsers = [
          {
            name = "hindsight";
            ensureDBOwnership = true;
          }
        ];
      };
      fileSystems.${pgDir} = {
        device = cfg.dataDir;
        fsType = "none";
        options = [
          "bind"
          "nofail"
          "x-systemd.requires-mounts-for=${cfg.backup.mountPoint}"
        ];
        depends = [ cfg.backup.mountPoint ];
      };
      systemd.services.hindsight-storage = {
        requiredBy = [ "postgresql.service" ];
        before = [ "postgresql.service" ];
        unitConfig = {
          RequiresMountsFor = [ pgDir ];
          ConditionPathIsMountPoint = pgDir;
        };
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          ${pkgs.btrfs-progs}/bin/btrfs subvolume show ${lib.escapeShellArg cfg.dataDir} >/dev/null
          ${pkgs.coreutils}/bin/chown postgres:postgres ${lib.escapeShellArg pgDir}
          ${pkgs.coreutils}/bin/chmod 0700 ${lib.escapeShellArg pgDir}
        '';
      };
      systemd.services.postgresql.unitConfig = {
        RequiresMountsFor = [ pgDir ];
        ConditionPathIsMountPoint = pgDir;
      };
      systemd.services.hindsight-database = {
        requiredBy = [ "hindsight.service" ];
        before = [ "hindsight.service" ];
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
        serviceConfig = {
          Type = "oneshot";
          User = "postgres";
          ExecStart = "${config.services.postgresql.package}/bin/psql --dbname=hindsight --set=ON_ERROR_STOP=1 --command='CREATE EXTENSION IF NOT EXISTS vector'";
        };
      };
      systemd.services.hindsight = {
        description = "Shared Hindsight memory API";
        wantedBy = [ "multi-user.target" ];
        after = [ "postgresql.target" ];
        requires = [ "postgresql.target" ];
        environment = {
          HINDSIGHT_API_DATABASE_URL = "postgresql://hindsight@/hindsight?host=/run/postgresql";
          HINDSIGHT_API_LLM_PROVIDER = "openai";
          HINDSIGHT_API_LLM_BASE_URL = "https://openrouter.ai/api/v1";
          HINDSIGHT_API_LLM_MODEL = models.memory.model;
          HINDSIGHT_API_LLM_REASONING_EFFORT = "low";
          HINDSIGHT_API_LLM_EXTRA_BODY = builtins.toJSON {
            provider = {
              order = hosts;
              only = hosts;
              zdr = true;
              data_collection = "deny";
              require_parameters = true;
            };
          };
          HINDSIGHT_API_EMBEDDINGS_PROVIDER = "openai";
          HINDSIGHT_API_EMBEDDINGS_OPENAI_BASE_URL = "https://openrouter.ai/api/v1";
          HINDSIGHT_API_EMBEDDINGS_OPENAI_MODEL = models.embeddings.model;
          HINDSIGHT_API_EMBEDDINGS_OPENAI_DIMENSIONS = toString models.embeddings.dimensions;
          HINDSIGHT_API_RERANKER_PROVIDER = models.reranker.provider;
          HINDSIGHT_API_RERANKER_OPENROUTER_MODEL = models.reranker.model;
          HINDSIGHT_API_RERANKER_MAX_CANDIDATES_MID = toString models.reranker.maxCandidates;
          HINDSIGHT_API_RERANKER_MAX_TOKENS_PER_CANDIDATE = toString models.reranker.maxTokensPerCandidate;
          HINDSIGHT_API_DB_POOL_MIN_SIZE = toString cfg.poolMin;
          HINDSIGHT_API_DB_POOL_MAX_SIZE = toString cfg.poolMax;
          HINDSIGHT_API_TENANT_EXTENSION = "hindsight_api.extensions.builtin.tenant:ApiKeyTenantExtension";
          HINDSIGHT_API_MCP_ENABLED_TOOLS = "retain,sync_retain,recall,get_mental_model,invalidate_memory,get_operation,list_operations,list_memories,get_memory,list_documents,get_document,delete_document,reflect";
          DO_NOT_TRACK = "1";
          HF_HUB_OFFLINE = "1";
        };
        serviceConfig = {
          User = "hindsight";
          Group = "hindsight";
          EnvironmentFile = config.sops.templates."hindsight.env".path;
          ExecStart = "${lib.getExe pkgs.hindsight-api-slim} --host 127.0.0.1 --port ${toString cfg.port}";
          Restart = "on-failure";
          RestartSec = 5;
          StateDirectory = "hindsight";
          WorkingDirectory = "/var/lib/hindsight";
          UMask = "0077";
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = true;
          ProtectSystem = "strict";
          RestrictSUIDSGID = true;
        };
      };
      systemd.services.hindsight-bank-template = {
        description = "Apply the declarative Hindsight bank template";
        wantedBy = [ "multi-user.target" ];
        after = [ "hindsight.service" ];
        partOf = [ "hindsight.service" ];
        script = ''
          # An import needs the models, which a starting API does not have yet: after= orders the
          # unit against the start job, not against the port, and a cold boot here took 98 seconds
          ${lib.getExe pkgs.curl} --silent --show-error --fail --retry 300 --retry-delay 2 \
            --retry-all-errors --retry-max-time 600 \
            "http://127.0.0.1:${toString cfg.port}/health" >/dev/null
          ${lib.getExe pkgs.curl} --silent --show-error --fail-with-body \
            --retry 30 --retry-delay 2 --retry-connrefused \
            -H "Authorization: Bearer $(${pkgs.coreutils}/bin/cat ${config.sops.secrets.hindsight-api-token.path})" \
            -H "Content-Type: application/json" \
            --data-binary @${bankTemplate} \
            "http://127.0.0.1:${toString cfg.port}/v1/default/banks/${cfg.bank}/import"
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          # The readiness wait above is bounded here, so a database that never comes up fails the
          # unit instead of holding it forever
          TimeoutStartSec = "15min";
        };
      };
      rokokol.tailnet-web.sites.hindsight = {
        port = cfg.publicPort;
        backend = "http://127.0.0.1:${toString cfg.port}";
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 900s;
        '';
      };
    })
  ];
}
