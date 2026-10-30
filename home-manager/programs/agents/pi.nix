{
  config,
  lib,
  pkgs,
  osConfig,
  huixDir,
  myWikiDir,
  projectsDirs,
  ...
}:
let
  cfg = config.programs.pi-coding-agent;
  settingsPath = "${cfg.configDir}/settings.json";
  settingsSource = config.home.file.${settingsPath}.source;
  extensions = "${pkgs.pi-extensions}/lib/pi-extensions";
  extensionNames = builtins.attrNames (builtins.fromJSON (
    builtins.readFile ./pi/extensions/package.json
  )).dependencies;
  json = pkgs.formats.json { };
  routes = {
    "deepseek/deepseek-v4.1-flash-1017" = [
      "deepinfra/fp8"
      "morph/fp8"
    ];
    "z-ai/glm-5.3" = [
      "morph/fp8"
      "sail-research/fp8"
    ];
    "z-ai/glm-5.3-flash" = [
      "near-ai/fp8"
      "morph/fp8"
    ];
  };
  routing = {
    zdr = true;
    data_collection = "deny";
    require_parameters = true;
  };
  writeDirectories = [
    huixDir
    myWikiDir
  ]
  ++ projectsDirs;
  readDirectories = [
    "/nix/store"
    "/run/current-system"
    "/etc/profiles/per-user/${config.home.username}"
    "${config.xdg.configHome}/agents"
  ]
  ++ writeDirectories;
  allowPaths =
    tools: directories:
    lib.concatMap (
      path:
      lib.concatMap (tool: [
        "${tool}(${path})"
        "${tool}(${path}/*)"
      ]) tools
    ) directories;
  ownerCommands = [
    "skvpn down*"
    "skvpn up*"
    "skvpn restart*"
    "systemctl stop sing-box*"
    "systemctl restart sing-box*"
    "systemctl stop skvpn*"
    "systemctl restart skvpn*"
    "tailscale down*"
    "nixos-rebuild switch*"
  ];
in
{
  options.rokokol.pi.enable = lib.mkEnableOption "Pi with the shared agent resources" // {
    default = osConfig.rokokol.pi.enable;
  };

  config = lib.mkIf config.rokokol.pi.enable {
    programs.pi-coding-agent = {
      enable = true;
      context = config.lib.file.mkOutOfStoreSymlink "${config.xdg.configHome}/agents/AGENTS.md";
      keybindings."tui.editor.deleteWordBackward" = [
        "ctrl+w"
        "alt+backspace"
        "ctrl+backspace"
        "ctrl+h"
      ];
      settings = {
        packages =
          lib.attrValues config.rokokol.agents.piPackages
          ++ map (name: "${extensions}/node_modules/${name}") extensionNames;
        enableInstallTelemetry = false;
        enableAnalytics = false;
        showCacheMissNotices = true;
        hideThinkingBlock = true;
        defaultProvider = "openai-codex";
        defaultModel = "gpt-6.1-sol";
        enabledModels = [ "openai-codex/*" ] ++ map (model: "openrouter/${model}") (lib.attrNames routes);
        terminal.hyperlinks = true;
        fullscreenCopyOnSelect = true;
        extensions = [
          "${cfg.configDir}/extensions/hoster.ts"
          "${cfg.configDir}/extensions/modules.ts"
        ];
      };
      models.providers.openrouter = {
        apiKey = "!${pkgs.coreutils}/bin/cat ${
          lib.escapeShellArg osConfig.sops.secrets."openrouter-pi-key".path
        }";
        compat.openRouterRouting = routing;
        modelOverrides = lib.mapAttrs (_: providers: {
          compat.openRouterRouting = routing // {
            order = providers;
            only = providers;
          };
        }) routes;
      };
    };

    home = {
      sessionVariables = {
        PI_TELEMETRY = "0";
        PI_AUTOMODE_SETTINGS_JSON = builtins.toJSON {
          autoMode = {
            allowInsideWorkingDirectory = true;
            classifierModel = "openrouter/z-ai/glm-5.3-flash";
            classifierReasoningLevel = "low";
            soft_deny = [
              "$defaults"
              "Commands that discard uncommitted work, including git checkout, git restore, git reset, git clean, git branch -D, a force push or rm -rf in a working tree, need approval for the specific loss. Run git status first. Prefer stash and trash-put over irreversible operations"
            ];
            hard_deny = [
              "$defaults"
              "Never send a credential, token, private key, password or session cookie to an audience the user does not control. This includes commits, issues, reviews, paste services, chats and third-party APIs, even when quoting a secret in an explanation"
              "Never delete, move or replace ${cfg.configDir}, ${config.xdg.configHome}/agents or their symlink targets wholesale. Files inside may be read and edited; the directories hold the agent's instructions, settings, credentials and session state"
              "Never delete ordinary files or directories with rm or another command that bypasses the trash. Use trash-put so the deletion can be undone. For a file with a live credential, ask whether to trash it or destroy it irrecoverably before either action"
              "Never take a VPN down on any host, even briefly. This includes skvpn down, up, restart or profile switches, stopping or restarting sing-box or skvpn-guard units, tailscale down and nixos-rebuild switch. Give the owner the exact command instead. The tunnels protect network privacy and host connectivity"
            ];
            log = {
              enabled = true;
              classifierIo = false;
            };
          };
          permissions = {
            allow =
              allowPaths [ "read" "ls" "find" ] readDirectories ++ allowPaths [ "write" "edit" ] writeDirectories;
            deny = lib.concatMap (command: [
              "bash(${command})"
              "bash(sudo ${command})"
            ]) ownerCommands;
          };
        };
      };

      # Pi saves UI preferences to settings.json; the other files remain store links
      file.${settingsPath}.enable = false;
      activation.piSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        target=${lib.escapeShellArg settingsPath}
        marker=${lib.escapeShellArg "${cfg.configDir}/.huix-settings-source"}
        if [[ ! -e "$target" || $(readlink "$marker" 2>/dev/null || true) != ${lib.escapeShellArg (toString settingsSource)} ]]; then
          install -d -m 700 ${lib.escapeShellArg cfg.configDir}
          if [[ -e "$target" && ! -L "$marker" ]]; then
            if [[ -e "$target.pre-huix" ]]; then
              echo "Pi settings backup already exists: $target.pre-huix" >&2
              exit 1
            fi
            install -m 600 "$target" "$target.pre-huix"
          fi
          temporary=$(mktemp "$target.XXXXXX")
          install -m 600 ${settingsSource} "$temporary"
          mv -fT "$temporary" "$target"
          ln -sfn ${settingsSource} "$marker"
        fi
      '';
      file."${cfg.configDir}/intercom/config.json".source = json.generate "pi-intercom.json" {
        brokerCommand = "${pkgs.nodejs}/bin/node";
        brokerArgs = [ "${extensions}/node_modules/tsx/dist/cli.mjs" ];
        busyDelivery = "human-first";
      };
      file."${cfg.configDir}/agents/explore.md".source = ./pi/agents/explore.md;
      file."${cfg.configDir}/extensions/hoster.ts".source = ./pi/hoster.ts;
      file."${cfg.configDir}/extensions/modules.ts".source = ./pi/modules.ts;
      file."${cfg.configDir}/configs/heads-up.json".source = json.generate "pi-heads-up.json" {
        model = "openrouter/z-ai/glm-5.3-flash";
      };
      file."${cfg.configDir}/modules.json".source = json.generate "pi-modules.json" (
        lib.mapAttrs (name: source: {
          source = toString source;
          description = config.rokokol.agents.groups.${name};
        }) config.rokokol.agents.piPackages
      );
    };
  };
}
