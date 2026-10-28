{
  config,
  lib,
  pkgs,
  inputs,
  ...
}:

# Nix owns service boundaries; Hermes owns its memory, skills and scheduled prompts
let
  agent = config.rokokol.mya-agent;
  cfg = agent.hermes;
  home = config.home-manager.users.${agent.user};
  # Replace the upstream all group without a second package recipe
  package = inputs.hermes-agent.packages.${pkgs.stdenv.hostPlatform.system}.default.override {
    extraDependencyGroups = [ ];
    callPackage =
      path: args:
      pkgs.callPackage path (
        args
        // lib.optionalAttrs (toString path == "${inputs.hermes-agent}/nix/python.nix") {
          dependency-groups = lib.unique (
            config.services.hermes-agent.extraDependencyGroups
            ++ lib.remove "all" (args.dependency-groups or [ ])
          );
        }
      );
    pmPackages =
      let
        packages = pkgs.callPackage "${inputs.hermes-agent}/nix/pm-packages.nix" { };
      in
      packages
      // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
        # See WORKAROUNDS.md: Hermes Node needs RPATH before the ELF interpreter
        node = packages.node.overrideAttrs (old: {
          nativeBuildInputs = with pkgs; [ patchelf ];
          dontFixup = true;
          installPhase = old.installPhase + ''
            patchelf --set-rpath ${pkgs.stdenv.cc.cc.lib}/lib:${pkgs.glibc}/lib "$out/bin/node"
            patchelf --set-interpreter ${pkgs.stdenv.cc.bintools.dynamicLinker} "$out/bin/node"
          '';
          doInstallCheck = true;
          installCheckPhase = ''
            "$out/bin/node" --version
            "$out/bin/node" -e 'require("node:child_process").execFileSync(process.execPath, ["--version"], {stdio: "inherit"})'
          '';
        });
      };
  };
  skills = pkgs.linkFarm "hermes-external-skills" home.rokokol.agents.skills;
  hmMcp = inputs.home-manager.lib.hm.mcp;
  mcpServers = lib.mapAttrs (
    name: server:
    hmMcp.transformMcpServer {
      inherit server;
      exclude = [ "type" ];
      extraTransforms = [ (hmMcp.wrapEnvFilesCommand { inherit pkgs name; }) ];
    }
  ) (lib.filterAttrs (_: server: server.enabled or null != false) home.programs.mcp.servers);
  mcpPackages = lib.mapAttrs (
    name: server:
    pkgs.writeShellScriptBin "hermes-mcp-${name}" ''
      exec ${lib.escapeShellArgs ([ (toString server.command) ] ++ (server.args or [ ]))} "$@"
    ''
  ) (lib.filterAttrs (_: server: server ? command) mcpServers);
  model = "deepseek/deepseek-v4.1-flash-1017";
  providers = [
    "deepinfra/fp8/flex"
    "deepinfra/fp8"
    "inference-net/fp8"
    "novita/fp8"
    "morph/fp8"
    "crusoe/fp8"
    "nebius/fp8"
    "siliconflow/fp8"
    "parasail/fp8"
  ];
  routing = {
    order = providers;
    only = providers;
    data_collection = "deny";
    require_parameters = true;
    # Only the auxiliary calls send it: Hermes builds the main agent's routing from a fixed list
    # of keys without zdr, so the main model's requests go without zero data retention
    zdr = true;
  };
  auxiliary = {
    provider = "openrouter";
    inherit model;
    extra_body.provider = routing;
  };
  # Every start adds a server that the shared registry gained, so a new one needs no second list
  seedFile = (pkgs.formats.json { }).generate "hermes-seed.json" {
    mcp_servers = lib.mapAttrs (
      name: server:
      server
      // lib.optionalAttrs (mcpPackages ? ${name}) {
        command = "/etc/profiles/per-user/${agent.user}/bin/hermes-mcp-${name}";
        args = [ ];
      }
    ) mcpServers;
  };
  # Only an empty state takes these; afterwards they live in config.yaml and its backup
  initialSettings = (pkgs.formats.json { }).generate "hermes-initial-settings.json" {
    memory = {
      provider = "builtin";
      user_char_limit = 24000;
      memory_char_limit = 16000;
      nudge_interval = 10;
      write_approval = false;
    };
    curator.consolidate = true;
    display.memory_notifications = "verbose";
    agent = {
      reasoning_effort = "medium";
      max_turns = 60;
    };
    # A scheduled report arrives as the agent's answer alone
    cron.wrap_response = false;
  };
  seedScript = builtins.path {
    name = "hermes-seed-config.py";
    path = "${inputs.self}/scripts/hermes-seed-config.py";
  };
  # Fills an empty state; a state restored from a backup needs none of it
  bootstrap = pkgs.writeShellApplication {
    name = "hermes-bootstrap";
    runtimeInputs = with pkgs; [ systemd ];
    text = ''
      exec ${package.hermesVenv}/bin/python3 ${
        builtins.path {
          name = "hermes-bootstrap.py";
          path = "${inputs.self}/scripts/hermes-bootstrap.py";
        }
      } \
        --home ${agent.home}/.hermes \
        --seed-script ${seedScript} \
        --initial-settings ${initialSettings} \
        "$@"
    '';
  };
  guests = lib.filterAttrs (
    _: host: host.config.rokokol.mya-agent.guest.enable
  ) inputs.self.nixosConfigurations;
  secret = name: config.sops.placeholder.${name};
  notifyScript = builtins.path {
    name = "hermes-notify.py";
    path = "${inputs.self}/scripts/hermes-notify.py";
  };
  notify = pkgs.writeShellApplication {
    name = "mya-agent-notify";
    text = ''
      exec ${lib.getExe pkgs.python3} ${notifyScript} \
        --secret-file ${config.sops.secrets.hermes-webhook-secret.path} \
        --url http://127.0.0.1:${toString cfg.webhookPort}/webhooks/alerts "$@"
    '';
  };
  sandbox = {
    ProtectHome = lib.mkForce "tmpfs";
    ProtectSystem = "strict";
    PrivateTmp = true;
    # A separate user namespace blocks access through another same-UID process's root
    PrivateUsers = true;
    NoNewPrivileges = true;
    MemoryMax = cfg.memoryMax;
    TemporaryFileSystem = map (path: "${path}:ro") agent.hiddenPaths;
    BindPaths = [ agent.home ] ++ lib.attrValues agent.directories;
    UMask = lib.mkForce "0077";
  };
in
{
  imports = [ inputs.hermes-agent.nixosModules.default ];

  options.rokokol.mya-agent.notify = lib.mkOption {
    type = lib.types.nullOr lib.types.path;
    readOnly = true;
    default = if agent.enable then lib.getExe notify else null;
    defaultText = lib.literalMD "The signed Hermes webhook command, or null when the agent is off";
    description = "Command that delivers an alert to the agent webhook";
  };

  options.rokokol.mya-agent.hermes = {
    webhookPort = lib.mkOption {
      type = lib.types.port;
      default = 8644;
      description = "Loopback port of the signed alert webhook";
    };
    dashboardPort = lib.mkOption {
      type = lib.types.port;
      default = 9120;
      description = "Tailnet port of the Hermes web dashboard";
    };
    dashboardAutoStart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Start the dashboard at boot after its memory use has been measured";
    };
    homeTopic = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 41;
      description = "Topic of the owner's chat that is Hermes' home channel, for gateway notices";
    };
    cronTopic = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = cfg.homeTopic;
      defaultText = lib.literalExpression "config.rokokol.mya-agent.hermes.homeTopic";
      example = 43;
      description = "Topic of the owner's chat that takes cron jobs aimed at the home channel, and the spend of cron sessions";
    };
    reportsTopic = lib.mkOption {
      type = lib.types.nullOr lib.types.ints.positive;
      default = null;
      example = 42;
      description = "Topic of the owner's chat that takes station alerts, balance notices and the spend of sessions that run outside the chat; a chat session hears of its spend where it runs";
    };
    memoryMax = lib.mkOption {
      type = lib.types.str;
      default = "1200M";
      description = "Memory limit of each Hermes service";
    };
  };

  config = lib.mkIf agent.enable {
    users.users.${agent.user} = {
      linger = true;
      packages = [
        package
        bootstrap
      ]
      ++ lib.attrValues mcpPackages;
    };

    sops.secrets = lib.genAttrs [
      "openrouter-api-key"
      "telegram-bot-token"
      "telegram-owner-chat-id"
      "hermes-webhook-secret"
      "hermes-dashboard-password"
      "hermes-dashboard-secret"
    ] (_: { });
    sops.templates."hermes.env" = {
      group = agent.user;
      mode = "0440";
      restartUnits = [
        "hermes-agent.service"
        "hermes-backend.service"
      ];
      content = ''
        OPENROUTER_API_KEY=${secret "openrouter-api-key"}
        TELEGRAM_BOT_TOKEN=${secret "telegram-bot-token"}
        TELEGRAM_ALLOWED_USERS=${secret "telegram-owner-chat-id"}
        TELEGRAM_HOME_CHANNEL=${secret "telegram-owner-chat-id"}
        WEBHOOK_SECRET=${secret "hermes-webhook-secret"}
        HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${secret "hermes-dashboard-password"}
        HERMES_DASHBOARD_BASIC_AUTH_SECRET=${secret "hermes-dashboard-secret"}
        HERMES_MANAGED=false
        HERMES_DASHBOARD_BASIC_AUTH_USERNAME=rokokol
      ''
      + lib.optionalString (cfg.homeTopic != null) ''
        TELEGRAM_HOME_CHANNEL_THREAD_ID=${toString cfg.homeTopic}
      ''
      + lib.optionalString (cfg.cronTopic != null) ''
        TELEGRAM_CRON_THREAD_ID=${toString cfg.cronTopic}
      '';
    };
    environment.etc."hermes/.env".source = config.sops.templates."hermes.env".path;
    environment.etc."hermes/config.yaml".source =
      (pkgs.formats.yaml { }).generate "hermes-policy.yaml"
        {
          curator.prune_builtins = false;
        };

    services.hermes-agent = {
      enable = true;
      inherit package;
      inherit (agent) user;
      group = agent.user;
      createUser = false;
      stateDir = agent.home;
      workingDirectory = agent.home;
      extraDependencyGroups = [
        "mcp"
        "acp"
        "google"
        "youtube"
        "web"
        "uvloop"
        "messaging"
        "otlp"
      ];
      hermesHomeFiles.".managed" = "false";
      backend = {
        mode = "dashboard";
        host = "127.0.0.1";
        port = cfg.dashboardPort + 1;
      };
      settings = {
        model = {
          provider = "openrouter";
          default = model;
        };
        provider_routing = routing;
        # A planned stop lets a running turn finish this long before interrupting it, which
        # pauses its session until /discard; it stays under systemd's default stop timeout of 90
        agent.restart_drain_timeout = 30;
        auxiliary = lib.genAttrs [
          "compression"
          "title_generation"
          "curator"
          "background_review"
          "approval"
          "vision"
          "review"
          "monitor"
          "mcp"
          "memory_query_rewrite"
          "goal_judge"
          "kanban_decomposer"
          "moa_aggregator"
          "moa_reference"
          "profile_describer"
          "skills_hub"
          "triage_specifier"
          "tts_audio_tags"
          "voice_chat"
        ] (_: auxiliary);
        skills.external_dirs = [ "${skills}" ];
        display = {
          language = "en";
        };
        approvals = {
          mode = "smart";
          cron_mode = "deny";
          deny = [ "sudo *" ];
        };
        dashboard.public_url = "http://${config.networking.hostName}:${toString cfg.dashboardPort}";
        platforms = {
          telegram = {
            enabled = true;
            extra = {
              reactions = false;
              rich_messages = true;
              rich_drafts = false;
            };
          };
          webhook = {
            enabled = true;
            extra = {
              host = "127.0.0.1";
              port = cfg.webhookPort;
              # Each agent run of a webhook takes a session of its own, so an alert goes to the
              # chat as it is and joins the chat's session; the agent reads it when the owner answers
              routes.alerts = {
                deliver_only = true;
                prompt = "Station alert: {text}";
                deliver = "telegram";
                mirror_to_session = true;
              }
              // lib.optionalAttrs (cfg.reportsTopic != null) {
                deliver_extra.message_thread_id = toString cfg.reportsTopic;
              };
            };
          };
        };
      };
      documents."AGENTS.md" = ''
        # Communication

        Write all notifications, scheduled reports and hook output in English

        Ask the owner before you send mail or messages as the owner, or publish under the owner's identity

        When a request is unclear, or the next step depends on a choice that is the owner's, ask with the clarify tool and offer the options as choices

        Before you create, patch or delete a skill, a background review included, read the skill-authoring skill with skill_view and follow it

        # System and configuration

        You run on ${config.networking.hostName}, which uses NixOS. Your huix checkout is at ${agent.home}/huix

        Read that repository's instructions before you change its configuration

        Nix owns installed packages and system services. Use the flake for permanent changes

        Use nix run for a temporary command from a verified package or flake output

        You have no sudo. The owner builds and deploys system changes

        Your editable settings are in ~/.hermes/config.yaml. Nix supplies infrastructure settings at activation

        Never print secrets, full environment dumps, credential files or decrypted sops documents into tool output

        # Hosts

        SSH hosts and users

        ${lib.concatStrings (
          lib.mapAttrsToList (name: host: "- `${name}`: `${host.config.rokokol.mya-agent.user}`\n") guests
        )}
        # DDLC style

        Take DDLC colours, roles, the web kit and the report style from ddlc-themes at ${inputs.ddlc-themes}, the version the owner's hosts use; its README lists what it ships. Never type a colour by hand. In matplotlib use plt.style.use("ddlc"). The Doki and Nunito faces are installed

        # Heavy computation

        The PC is the compute host: send long work there over `ssh nixos-pc` instead of running it on the station, which carries the agent and its services beside the calculation

        That covers the CPU and CUDA sides alike — simulations, numeric sweeps, compiles, anything that wants minutes of a machine

        Read the `power` skill for how a host is woken, slept or shut down

        Ask the owner before you shut the PC down or suspend it — the skill's leave to act on your own does not reach that far

        # Notes

        The vault is at ~/myWiki. Read its instructions before you edit notes

        The English vocabulary is at ~/myWiki/05. Конспекты/14. Английский/Слова.md

        Read ~/myWiki/.claude/skills/fsrs-vocabulary/SKILL.md before you add a vocabulary entry

        # GitHub

        gh uses a local proxy. The proxy holds the tokens. Leave notifications unread unless the owner asks otherwise

      '';
    };

    systemd.services.hermes-agent = {
      environment = lib.mapAttrs (_: toString) home.home.sessionVariables // {
        HERMES_MANAGED = lib.mkForce "false";
      };
      after = [ "home-manager-${agent.user}.service" ];
      path = [
        "/etc/profiles/per-user/${agent.user}"
        "/run/current-system/sw"
      ];
      unitConfig.RequiresMountsFor = lib.attrValues agent.directories;
      serviceConfig = sandbox // {
        EnvironmentFile = config.sops.templates."hermes.env".path;
        # Nix gives only the first value of these settings; later edits belong to Hermes
        ExecStartPre = "${package.hermesVenv}/bin/python3 ${seedScript} ${seedFile} ${agent.home}/.hermes/config.yaml";
        # Hermes takes SIGINT for a planned stop; on SIGTERM it exits 1 so that a supervisor
        # revives it, and every stop or deploy would then fail the unit and mail an alert
        KillSignal = "SIGINT";
      };
    };
    systemd.services.hermes-backend = {
      environment = lib.mapAttrs (_: toString) home.home.sessionVariables // {
        HERMES_MANAGED = lib.mkForce "false";
      };
      wantedBy = lib.mkForce (lib.optional cfg.dashboardAutoStart "multi-user.target");
      after = [ "home-manager-${agent.user}.service" ];
      unitConfig.RequiresMountsFor = lib.attrValues agent.directories;
      serviceConfig = sandbox // {
        EnvironmentFile = config.sops.templates."hermes.env".path;
      };
    };
    rokokol.tailnet-web.sites.hermes = {
      port = cfg.dashboardPort;
      backend = "http://127.0.0.1:${toString config.services.hermes-agent.backend.port}";
      extraConfig = ''
        proxy_read_timeout 3600s;
        proxy_send_timeout 3600s;
      '';
    };
  };
}
