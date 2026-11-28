{
  config,
  lib,
  pkgs,
  inputs,
  myWikiDir,
  rokokolName,
  ...
}:

let
  cfg = config.rokokol.obsidian-thing;
  app = config.obsidian-thing;
  inherit (import ../../../lib/ai-models.nix) vaultEmbeddings;
  archive = config.rokokol.syncthing.archive;
  sync = config.services.syncthing;
  vaultToken = "obsidian-thing-vault-token";
  clientToken = "obsidian-thing-client-token";
  secretsFile = builtins.path {
    name = "huix-obsidian-thing-secrets";
    path = "${inputs.self}/secrets/obsidian-thing.yaml";
  };
  metricsToken = "obsidian-thing-metrics-token";
  providerKey = "openrouter-my-wiki-key";
  spendUnit = "obsidian-thing-key-spend";
  spendMetrics = "/run/${spendUnit}/metrics.prom";
  spendCollector = builtins.path {
    name = "hindsight-monitor.py";
    path = "${inputs.self}/scripts/hindsight-monitor.py";
  };
  vaultChecker = pkgs.writeText "mywiki-checker-entry.py" ''
    import os
    import runpy
    import sys

    # The server runs a checker with its own interpreter, and that environment has no PyYAML,
    # which the vault policy imports. Re-exec the policy under an interpreter that does; the
    # inherited PYTHONPATH still supplies the server packages the policy also reads
    HERE = ${builtins.toJSON "${checkerSource}"}
    PYTHON = ${builtins.toJSON "${checkerPython}/bin/python3"}
    try:
        import yaml
    except ModuleNotFoundError:
        os.execv(PYTHON, [PYTHON, "-s", "-P", "-X", "utf8", HERE + "/checker.py", *sys.argv[1:]])
    runpy.run_path(HERE + "/checker.py", run_name="__main__")
  '';
  checkerSource = builtins.path {
    name = "mywiki-write-checker";
    path = "${inputs.self}/scripts/mywiki-checker";
  };
  checkerPython = pkgs.python3.withPackages (ps: [
    ps.pyyaml
    ps.markdown-it-py
    ps.mdit-py-plugins
  ]);
  env = "obsidian-thing.env";
  vaultEnv = "OBSIDIAN_THING_VAULT_TOKEN";
  metricsEnv = "OBSIDIAN_THING_METRICS_TOKEN";
  providerEnv = "OBSIDIAN_THING_OPENROUTER_KEY";
  tailnetPort = 8767;
  tailnetAuthority = "nixos-station:${toString tailnetPort}";
  endpoint = "http://${app.host}:${toString app.port}";
  mcpPath = "/vaults/mywiki/mcp";
  folders = [
    "02. Zettelkasten"
    "03. Записки"
    "04. Книжная полка"
  ];
  attachments = "00. Вложения";
  gallery = "${attachments}/01. Gallery";
  registerClient = tokenFile: origin: {
    command = lib.getExe (
      pkgs.writeShellApplication {
        name = "obsidian-thing-mcp";
        text = ''
          API_ACCESS_TOKEN=$(<${lib.escapeShellArg tokenFile})
          test -n "$API_ACCESS_TOKEN"
          export API_ACCESS_TOKEN
          unset HTTP_PROXY HTTPS_PROXY ALL_PROXY http_proxy https_proxy all_proxy
          exec ${lib.getExe pkgs.mcp-proxy} --transport streamablehttp ${lib.escapeShellArg "${origin}${mcpPath}"}
        '';
      }
    );
  };
in
{
  imports = [ inputs.obsidian-thing.nixosModules.default ];

  options.rokokol.obsidian-thing = {
    enable = lib.mkEnableOption "Obsidian MCP for the synced vault";
    background = lib.mkEnableOption "automatic requests to the embedding provider";
    client.enable = lib.mkEnableOption "MCP access from this workstation";
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.client.enable {
      sops.secrets.${clientToken} = {
        sopsFile = secretsFile;
        key = "api-token";
        owner = rokokolName;
      };
      home-manager.users.${rokokolName}.programs.mcp.servers.obsidian-thing =
        registerClient config.sops.secrets.${clientToken}.path
          "http://${tailnetAuthority}";
    })
    (lib.mkIf cfg.enable {
      assertions = [
        {
          assertion = archive.enable && archive.editor != null;
          message = "Obsidian MCP needs a writable Syncthing archive.";
        }
        {
          assertion = config.services.tailscale.enable;
          message = "Obsidian MCP needs Tailscale for workstation access.";
        }
        {
          assertion = app.host == "127.0.0.1" && app.port != tailnetPort;
          message = "Obsidian MCP needs a separate loopback port for the backend.";
        }
      ];

      obsidian-thing = {
        enable = true;
        inherit (sync) user group;
        environmentFile = config.sops.templates.${env}.path;
        settings = {
          metrics_token_env = metricsEnv;
          allowed_hosts = [
            "${app.host}:${toString app.port}"
            tailnetAuthority
          ];
          vaults.mywiki = {
            root = archive.folders.${myWikiDir};
            allowed = [ "." ];
            writable = true;
            read_obsidian = true;
            token_env = vaultEnv;
            checks = {
              default_quotes = "\"\"";
              inner_quoter = "«»";
              trailing_periods = true;
              prevent_inline_tags = true;
              inline_code_equals = true;
              heading_math = true;
              unicode_math = true;
              link_math = true;
              paragraph_lines = true;
              callouts = true;
              broken_links = true;
              bases = true;
              canvas = true;
            };
            checker = {
              script = "${vaultChecker}";
              timeout_seconds = 5;
              vault_context_properties = [
                "aliases"
                "tags"
                "up"
                "prev"
                "next"
              ];
            };
            integrations = {
              media_gallery = true;
              iconic_offline = true;
              fsrs_dictionary = true;
            };
            indexing = {
              auto = true;
              exclude = [
                "/*"
              ]
              ++ map (folder: "!/${folder}/") folders
              ++ [
                "!/${attachments}/"
                "/${attachments}/*"
                "!/${gallery}/"
                "*.tmp"
                "*.swp"
                "*~"
              ];
            };
            embeddings = vaultEmbeddings // {
              key_env = providerEnv;
              allow_cloud = true;
              zdr = true;
              data_collection = "deny";
              inherit (cfg) background;
              include_paths = folders ++ [ gallery ];
              # Excalidraw notes carry their drawing payload as data, so the splitter sees one
              # oversized run of text rather than prose, and the file fails the chunk limit.
              # The vocabulary is a thousand dictionary rows that fsrs_list already serves
              exclude_paths = [
                "02. Zettelkasten/02. Excalidraw"
                "02. Zettelkasten/Слова.md"
              ];
              allowed_mime_types = [
                "text/markdown"
                "text/plain"
                "image/png"
                "image/jpeg"
                "application/pdf"
              ];
            };
          };
        };
      };

      sops.secrets = {
        ${vaultToken} = {
          sopsFile = secretsFile;
          key = "api-token";
          owner = sync.user;
        };
        ${providerKey} = { };
        ${metricsToken} = lib.optionalAttrs config.services.prometheus.enable {
          owner = config.systemd.services.prometheus.serviceConfig.User;
          mode = "0400";
          restartUnits = [ "prometheus.service" ];
        };
      };
      home-manager.users.${sync.user}.programs.mcp.servers.obsidian-thing =
        registerClient config.sops.secrets.${vaultToken}.path
          endpoint;

      sops.templates.${env} = {
        restartUnits = [ "obsidian-thing.service" ];
        content = ''
          ${vaultEnv}=${config.sops.placeholder.${vaultToken}}
          ${metricsEnv}=${config.sops.placeholder.${metricsToken}}
          ${providerEnv}=${config.sops.placeholder.${providerKey}}
        '';
      };

      systemd.services.obsidian-thing = {
        after = [ "syncthing.service" ];
        unitConfig = {
          RequiresMountsFor = [ archive.folders.${myWikiDir} ];
          ConditionPathIsMountPoint = archive.mountPoint;
        };
        serviceConfig.ProtectHome = lib.mkForce true;
      };

      services.prometheus.checkConfig = lib.mkIf config.services.prometheus.enable "syntax-only";
      services.prometheus.scrapeConfigs = lib.mkIf config.services.prometheus.enable [
        {
          job_name = "obsidian-thing";
          authorization = {
            type = "Bearer";
            credentials_file = config.sops.secrets.${metricsToken}.path;
          };
          static_configs = [
            {
              targets = [ "${app.host}:${toString app.port}" ];
              labels.host = config.networking.hostName;
            }
          ];
        }
      ];

      systemd.tmpfiles.rules = [
        "L+ ${config.rokokol.node-exporter.textfileDir}/${spendUnit}.prom - - - - ${spendMetrics}"
      ];
      systemd.services.obsidian-thing-key-spend = {
        description = "Export OpenRouter spend and limit for the Obsidian Thing key";
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        serviceConfig = {
          Type = "oneshot";
          # Not DynamicUser: systemd puts such a unit's runtime directory under /run/private, which
          # the unprivileged node-exporter cannot traverse, and the metrics never reach a scrape
          RuntimeDirectory = spendUnit;
          RuntimeDirectoryMode = "0755";
          RuntimeDirectoryPreserve = true;
          LoadCredential = "key:${config.sops.secrets.${providerKey}.path}";
          ExecStart = lib.escapeShellArgs [
            (lib.getExe pkgs.python3)
            spendCollector
            "--metrics"
            spendMetrics
            "--key-file"
            "%d/key"
            "--key-only-prefix"
            "obsidian_thing_spend"
          ];
          TimeoutStartSec = "30s";
          ProtectHome = true;
          ProtectSystem = "strict";
          PrivateTmp = true;
          PrivateDevices = true;
          NoNewPrivileges = true;
        };
      };
      systemd.timers.obsidian-thing-key-spend = {
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnActiveSec = "20s";
          OnUnitInactiveSec = "1m";
        };
      };

      rokokol.tailnet-web.sites.obsidian-thing = {
        port = tailnetPort;
        backend = endpoint;
        exactPath = mcpPath;
        extraConfig = ''
          proxy_buffering off;
          proxy_read_timeout 300s;
        '';
      };
    })
  ];
}
