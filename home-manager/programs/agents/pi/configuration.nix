{
  config,
  lib,
  pkgs,
  osConfig,
  ...
}:
let
  cfg = config.programs.pi-coding-agent;
  settingsPath = "${cfg.configDir}/settings.json";
  settingsSource = config.home.file.${settingsPath}.source;
  extensions = "${pkgs.pi-extensions}/lib/pi-extensions";
  extensionNames = builtins.attrNames (builtins.fromJSON (
    builtins.readFile ./extensions/package.json
  )).dependencies;
  json = pkgs.formats.json { };
  routes = (import ../../../../lib/ai-models.nix).chat;
  routing = {
    zdr = true;
    data_collection = "deny";
    require_parameters = true;
  };
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
        defaultModel = "gpt-6-luna";
        enabledModels = [ "openai-codex/*" ] ++ map (model: "openrouter/${model}") (lib.attrNames routes);
        terminal.hyperlinks = true;
        terminal.images = "kitty";
        fullscreenCopyOnSelect = true;
        extensions = [
          "-builtin:mcp"
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
      sessionVariables.PI_TELEMETRY = "0";

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
      file."${cfg.configDir}/agents/explore.md".source = ./agents/explore.md;
      file."${cfg.configDir}/extensions/hoster.ts".source = ./hoster.ts;
      file."${cfg.configDir}/extensions/modules.ts".source = ./modules.ts;
      file."${cfg.configDir}/configs/heads-up.json".source = json.generate "pi-heads-up.json" {
        model = "openrouter/z-ai/glm-5.3-flash";
      };
      file."${cfg.configDir}/modules.json".source = json.generate "pi-modules.json" (
        lib.mapAttrs (
          name: source:
          {
            source = toString source;
            description = config.rokokol.agents.groups.${name};
            servers = lib.attrNames (
              lib.filterAttrs (
                server: value:
                (value.enabled or null) != false
                && !(lib.elem server config.rokokol.agents.pi.exclude)
                && (config.rokokol.agents.mcpGroups.${server} or "huix") == name
              ) config.programs.mcp.servers
            );
          }
          // lib.optionalAttrs (builtins.hasAttr name config.rokokol.agents.moduleParents) {
            parent = config.rokokol.agents.moduleParents.${name};
          }
        ) config.rokokol.agents.piPackages
      );
    };
  };
}
